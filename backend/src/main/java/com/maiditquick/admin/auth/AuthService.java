package com.maiditquick.admin.auth;

import com.maiditquick.admin.admin.Admin;
import com.maiditquick.admin.admin.AdminRepository;
import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.auth.AuthExceptions.AccountDisabledException;
import com.maiditquick.admin.auth.AuthExceptions.InvalidCredentialsException;
import com.maiditquick.admin.auth.AuthExceptions.LoginLockedException;
import com.maiditquick.admin.common.HashUtil;
import com.maiditquick.admin.security.JwtService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Authentication service (US 1.1).
 *
 * Login flow: find admin by email -> enabled? -> locked? -> BCrypt verify ->
 * issue JWT (15 min) + random refresh token (hashed at rest, stored in MySQL).
 * Five failed attempts lock the account for 15 minutes (HTTP 429 while locked).
 * Successful login records {@code last_login} and resets the attempt counter.
 */
@Service
public class AuthService {

    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final Duration LOCK_DURATION = Duration.ofMinutes(15);

    private final AdminRepository admins;
    private final RefreshTokenRepository refreshes;
    private final PasswordEncoder passwords;
    private final JwtService jwt;
    private final AuditService audit;
    private final long refreshDays;

    public AuthService(
            AdminRepository admins,
            RefreshTokenRepository refreshes,
            PasswordEncoder passwords,
            JwtService jwt,
            AuditService audit,
            @Value("${app.jwt.refresh-days}") long refreshDays) {
        this.admins = admins;
        this.refreshes = refreshes;
        this.passwords = passwords;
        this.jwt = jwt;
        this.audit = audit;
        this.refreshDays = refreshDays;
    }

    /**
     * Authenticate an admin. Never reveals whether an email exists:
     * unknown account and wrong password both return 401.
     */
    public Tokens login(String email, String password, HttpServletRequest request) {
        Admin admin = admins.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password"));

        clearExpiredLock(admin);

        if (isLocked(admin)) {
            throw LoginLockedException.until(admin.getLockedUntil());
        }
        if (!admin.isEnabled()) {
            throw new AccountDisabledException("Account disabled");
        }
        if (!passwords.matches(password, admin.getPasswordHash())) {
            registerFailedAttempt(admin);
            throw new InvalidCredentialsException("Invalid email or password");
        }

        admin.setFailedAttempts(0);
        admin.setLockedUntil(null);
        admin.setLastLogin(Instant.now());
        admins.save(admin);

        return issue(admin, request);
    }

    /** Rotate a refresh token: revoke the presented one, issue a new pair. */
    public Tokens refresh(String raw, HttpServletRequest request) {
        RefreshToken stored = refreshes.findByTokenHashAndRevokedAtIsNull(hash(raw))
                .filter(t -> t.getExpiresAt().isAfter(Instant.now()))
                .orElseThrow(() -> new InvalidCredentialsException("Session expired"));

        stored.setRevokedAt(Instant.now());
        refreshes.save(stored);

        Admin admin = admins.findById(stored.getAdmin().getId())
                .orElseThrow(() -> new InvalidCredentialsException("Account unavailable"));

        return issue(admin, request);
    }

    /** Revoke a refresh token so it can never be used again. */
    public void logout(String raw) {
        refreshes.findByTokenHashAndRevokedAtIsNull(hash(raw))
                .ifPresent(t -> {
                    t.setRevokedAt(Instant.now());
                    refreshes.save(t);
                });
    }

    /**
     * M13 — change the admin's own password. The current password must match;
     * the new one is re-hashed (BCrypt) and every OTHER device session is
     * revoked (the session that presented the change keeps working).
     */
    @Transactional
    public void changePassword(Admin admin, String currentPassword, String newPassword,
                               String keepTokenRaw, HttpServletRequest request) {
        if (!passwords.matches(currentPassword, admin.getPasswordHash())) {
            audit.record("PASSWORD_CHANGE_FAILED", "AUTH", String.valueOf(admin.getId()),
                    null, "{\"reason\":\"wrong_current_password\"}", request);
            throw new InvalidCredentialsException("Current password is incorrect");
        }
        if (newPassword.equals(currentPassword)) {
            throw new IllegalArgumentException("New password must be different from the current password");
        }
        admin.setPasswordHash(passwords.encode(newPassword));
        admins.save(admin);

        int revoked;
        if (keepTokenRaw != null && !keepTokenRaw.isBlank()) {
            revoked = refreshes.revokeAllExcept(admin, hash(keepTokenRaw), Instant.now());
        } else {
            revoked = refreshes.revokeAllFor(admin, Instant.now());
        }
        audit.record("PASSWORD_CHANGED", "AUTH", String.valueOf(admin.getId()), null,
                "{\"otherSessionsRevoked\":" + revoked + "}", request);
    }

    /** M13 — active sessions of the current admin, newest first. */
    public List<SessionView> listSessions(Long adminId, String currentTokenRaw) {
        String currentHash = currentTokenRaw == null ? null : hash(currentTokenRaw);
        return refreshes.findByAdminIdAndRevokedAtIsNullOrderByIdDesc(adminId).stream()
                .map(t -> new SessionView(t.getId(), t.getIpAddress(), t.getUserAgent(),
                        t.getCreatedAt(), t.getLastUsedAt(), t.getExpiresAt(),
                        currentHash != null && currentHash.equals(t.getTokenHash())))
                .toList();
    }

    /**
     * M13 — revoke one session of the current admin. Returns true when the
     * revoked session was the caller's own (the browser cookie is then dead).
     */
    @Transactional
    public boolean revokeSession(Long adminId, Long sessionId, String currentTokenRaw, HttpServletRequest request) {
        RefreshToken stored = refreshes.findByIdAndAdminIdAndRevokedAtIsNull(sessionId, adminId)
                .orElseThrow(() -> new IllegalArgumentException("Session not found"));
        boolean wasCurrent = currentTokenRaw != null && stored.getTokenHash().equals(hash(currentTokenRaw));
        stored.setRevokedAt(Instant.now());
        refreshes.save(stored);
        audit.record("SESSION_REVOKED", "AUTH", String.valueOf(adminId), null,
                "{\"sessionId\":" + sessionId + ",\"revokedOwnSession\":" + wasCurrent + "}", request);
        return wasCurrent;
    }

    /** M13 — sign out everywhere: revoke every live session of the admin. */
    @Transactional
    public int signOutEverywhere(Admin admin, HttpServletRequest request) {
        int revoked = refreshes.revokeAllFor(admin, Instant.now());
        audit.record("SESSIONS_REVOKED_ALL", "AUTH", String.valueOf(admin.getId()), null,
                "{\"revoked\":" + revoked + "}", request);
        return revoked;
    }

    /* ---------------- internals ---------------- */

    private void clearExpiredLock(Admin admin) {
        if (admin.getLockedUntil() != null && !admin.getLockedUntil().isAfter(Instant.now())) {
            admin.setLockedUntil(null);
            admin.setFailedAttempts(0);
        }
    }

    private boolean isLocked(Admin admin) {
        return admin.getLockedUntil() != null && admin.getLockedUntil().isAfter(Instant.now());
    }

    private void registerFailedAttempt(Admin admin) {
        admin.setFailedAttempts(admin.getFailedAttempts() + 1);
        if (admin.getFailedAttempts() >= MAX_FAILED_ATTEMPTS) {
            admin.setLockedUntil(Instant.now().plus(LOCK_DURATION));
        }
        admins.save(admin);
    }

    private Tokens issue(Admin admin, HttpServletRequest request) {
        String raw = UUID.randomUUID() + "." + UUID.randomUUID();

        RefreshToken stored = new RefreshToken();
        stored.setAdmin(admin);
        stored.setTokenHash(hash(raw));
        stored.setExpiresAt(Instant.now().plus(Duration.ofDays(refreshDays)));
        stored.setIpAddress(request.getRemoteAddr());
        stored.setUserAgent(request.getHeader("User-Agent"));
        stored.setCreatedAt(Instant.now());
        stored.setLastUsedAt(Instant.now());
        refreshes.save(stored);

        List<String> permissions = admin.getRole().getPermissions().stream()
                .map(p -> p.getCode())
                .toList();

        return new Tokens(
                jwt.create(admin),
                raw,
                jwt.expiresInSeconds(),
                admin.getDisplayName(),
                permissions,
                new AdminInfo(admin.getId(), admin.getDisplayName(), admin.getEmail(), admin.getRole().getCode()));
    }

    /** Refresh tokens are stored only as SHA-256 digests. */
    private String hash(String value) {
        return HashUtil.sha256(value);
    }

    /* ---------------- response DTOs ---------------- */

    /** Login/refresh response: raw token payload (not envelope-wrapped). */
    public record Tokens(
            String accessToken,
            String refreshToken,
            long expiresIn,
            String name,
            List<String> permissions,
            AdminInfo admin) {
    }

    /** Compact admin summary included in the token payload. */
    public record AdminInfo(Long id, String name, String email, String role) {
    }

    /** M13 — one active session as shown on the profile page. */
    public record SessionView(Long id, String ipAddress, String userAgent,
                              Instant createdAt, Instant lastUsedAt, Instant expiresAt,
                              boolean current) {
    }
}
