package com.maiditquick.admin.auth;

import com.makeitquick.security.AdminPermissions;
import com.makeitquick.security.JwtService;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.auth.AuthExceptions.AccountDisabledException;
import com.maiditquick.admin.auth.AuthExceptions.InvalidCredentialsException;
import com.maiditquick.admin.auth.AuthExceptions.LoginLockedException;
import com.maiditquick.admin.common.HashUtil;
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
 * Admin authentication backed by the unified identity model ({@link UserAccount}
 * with {@link Role#ADMIN}). Login flow: find the account by email -> enabled?
 * -> locked? -> BCrypt verify -> issue a short-lived JWT from the shared
 * {@link JwtService} plus a hashed refresh token. Five failed attempts lock the
 * account for 15 minutes (HTTP 429 while locked).
 */
@Service
public class AuthService {

    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final Duration LOCK_DURATION = Duration.ofMinutes(15);

    private final UserRepository users;
    private final RefreshTokenRepository refreshes;
    private final PasswordEncoder passwords;
    private final JwtService jwt;
    private final AuditService audit;
    private final long accessMinutes;
    private final long refreshDays;

    public AuthService(
            UserRepository users,
            RefreshTokenRepository refreshes,
            PasswordEncoder passwords,
            JwtService jwt,
            AuditService audit,
            @Value("${app.security.admin-access-minutes:15}") long accessMinutes,
            @Value("${app.security.admin-refresh-days:7}") long refreshDays) {
        this.users = users;
        this.refreshes = refreshes;
        this.passwords = passwords;
        this.jwt = jwt;
        this.audit = audit;
        this.accessMinutes = accessMinutes;
        this.refreshDays = refreshDays;
    }

    /**
     * Authenticate an admin. Never reveals whether an email exists:
     * unknown account and wrong password both return 401.
     */
    public Tokens login(String email, String password, HttpServletRequest request) {
        UserAccount user = adminByEmail(email)
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password"));

        clearExpiredLock(user);

        if (isLocked(user)) {
            throw LoginLockedException.until(user.getLockedUntil());
        }
        if (!user.isEnabled()) {
            throw new AccountDisabledException("Account disabled");
        }
        if (!passwords.matches(password, user.getPasswordHash())) {
            registerFailedAttempt(user);
            throw new InvalidCredentialsException("Invalid email or password");
        }

        user.setFailedAttempts(0);
        user.setLockedUntil(null);
        user.setLastLogin(Instant.now());
        users.save(user);

        return issue(user, request);
    }

    /** Rotate a refresh token: revoke the presented one, issue a new pair. */
    public Tokens refresh(String raw, HttpServletRequest request) {
        RefreshToken stored = refreshes.findByTokenHashAndRevokedAtIsNull(hash(raw))
                .filter(t -> t.getExpiresAt().isAfter(Instant.now()))
                .orElseThrow(() -> new InvalidCredentialsException("Session expired"));

        stored.setRevokedAt(Instant.now());
        refreshes.save(stored);

        UserAccount user = users.findById(stored.getUser().getId())
                .orElseThrow(() -> new InvalidCredentialsException("Account unavailable"));

        return issue(user, request);
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
     * Change the admin's own password. The current password must match;
     * the new one is re-hashed (BCrypt) and every OTHER device session is
     * revoked (the session that presented the change keeps working).
     */
    @Transactional
    public void changePassword(UserAccount user, String currentPassword, String newPassword,
                               String keepTokenRaw, HttpServletRequest request) {
        if (!passwords.matches(currentPassword, user.getPasswordHash())) {
            audit.record("PASSWORD_CHANGE_FAILED", "AUTH", String.valueOf(user.getId()),
                    null, "{\"reason\":\"wrong_current_password\"}", request);
            throw new InvalidCredentialsException("Current password is incorrect");
        }
        if (newPassword.equals(currentPassword)) {
            throw new IllegalArgumentException("New password must be different from the current password");
        }
        user.setPasswordHash(passwords.encode(newPassword));
        users.save(user);

        int revoked;
        if (keepTokenRaw != null && !keepTokenRaw.isBlank()) {
            revoked = refreshes.revokeAllExcept(user, hash(keepTokenRaw), Instant.now());
        } else {
            revoked = refreshes.revokeAllFor(user, Instant.now());
        }
        audit.record("PASSWORD_CHANGED", "AUTH", String.valueOf(user.getId()), null,
                "{\"otherSessionsRevoked\":" + revoked + "}", request);
    }

    /** Active sessions of the current admin, newest first. */
    public List<SessionView> listSessions(Long userId, String currentTokenRaw) {
        String currentHash = currentTokenRaw == null ? null : hash(currentTokenRaw);
        return refreshes.findByUserIdAndRevokedAtIsNullOrderByIdDesc(userId).stream()
                .map(t -> new SessionView(t.getId(), t.getIpAddress(), t.getUserAgent(),
                        t.getCreatedAt(), t.getLastUsedAt(), t.getExpiresAt(),
                        currentHash != null && currentHash.equals(t.getTokenHash())))
                .toList();
    }

    /**
     * Revoke one session of the current admin. Returns true when the revoked
     * session was the caller's own (the browser cookie is then dead).
     */
    @Transactional
    public boolean revokeSession(Long userId, Long sessionId, String currentTokenRaw, HttpServletRequest request) {
        RefreshToken stored = refreshes.findByIdAndUserIdAndRevokedAtIsNull(sessionId, userId)
                .orElseThrow(() -> new IllegalArgumentException("Session not found"));
        boolean wasCurrent = currentTokenRaw != null && stored.getTokenHash().equals(hash(currentTokenRaw));
        stored.setRevokedAt(Instant.now());
        refreshes.save(stored);
        audit.record("SESSION_REVOKED", "AUTH", String.valueOf(userId), null,
                "{\"sessionId\":" + sessionId + ",\"revokedOwnSession\":" + wasCurrent + "}", request);
        return wasCurrent;
    }

    /** Sign out everywhere: revoke every live session of the admin. */
    @Transactional
    public int signOutEverywhere(UserAccount user, HttpServletRequest request) {
        int revoked = refreshes.revokeAllFor(user, Instant.now());
        audit.record("SESSIONS_REVOKED_ALL", "AUTH", String.valueOf(user.getId()), null,
                "{\"revoked\":" + revoked + "}", request);
        return revoked;
    }

    /* ---------------- internals ---------------- */

    private java.util.Optional<UserAccount> adminByEmail(String email) {
        return users.findByEmailIgnoreCase(email)
                .filter(u -> u.getRole() == Role.ADMIN);
    }

    private void clearExpiredLock(UserAccount user) {
        if (user.getLockedUntil() != null && !user.getLockedUntil().isAfter(Instant.now())) {
            user.setLockedUntil(null);
            user.setFailedAttempts(0);
        }
    }

    private boolean isLocked(UserAccount user) {
        return user.getLockedUntil() != null && user.getLockedUntil().isAfter(Instant.now());
    }

    private void registerFailedAttempt(UserAccount user) {
        user.setFailedAttempts(user.getFailedAttempts() + 1);
        if (user.getFailedAttempts() >= MAX_FAILED_ATTEMPTS) {
            user.setLockedUntil(Instant.now().plus(LOCK_DURATION));
        }
        users.save(user);
    }

    private Tokens issue(UserAccount user, HttpServletRequest request) {
        String raw = UUID.randomUUID() + "." + UUID.randomUUID();

        RefreshToken stored = new RefreshToken();
        stored.setUser(user);
        stored.setTokenHash(hash(raw));
        stored.setExpiresAt(Instant.now().plus(Duration.ofDays(refreshDays)));
        stored.setIpAddress(request.getRemoteAddr());
        stored.setUserAgent(request.getHeader("User-Agent"));
        stored.setCreatedAt(Instant.now());
        stored.setLastUsedAt(Instant.now());
        refreshes.save(stored);

        return new Tokens(
                jwt.issue(user, Duration.ofMinutes(accessMinutes)),
                raw,
                accessMinutes * 60,
                user.getName(),
                AdminPermissions.ALL,
                new AdminInfo(user.getId(), user.getName(), user.getEmail(), "ADMIN"));
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

    /** One active session as shown on the profile page. */
    public record SessionView(Long id, String ipAddress, String userAgent,
                              Instant createdAt, Instant lastUsedAt, Instant expiresAt,
                              boolean current) {
    }
}
