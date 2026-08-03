package com.maiditquick.admin.auth;

import com.maiditquick.admin.admin.Admin;
import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.auth.AuthExceptions.InvalidResetTokenException;
import com.maiditquick.admin.common.HashUtil;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Reset-password flow (US 1.3).
 * The emailed token is redeemed here: it must exist, be unused and unexpired.
 * On success the admin password is re-hashed (BCrypt), the token is consumed
 * (single use), every refresh session is revoked so all devices must sign in
 * again with the new password, and the account lock is cleared.
 * Any unusable token (unknown, used, expired, or for a disabled account)
 * fails with the same generic 400 — no information leak.
 */
@Service
public class ResetPasswordService {

    private static final Logger log = LoggerFactory.getLogger(ResetPasswordService.class);

    private final PasswordResetTokenRepository resets;
    private final RefreshTokenRepository refreshes;
    private final PasswordEncoder passwords;
    private final AuditService audit;

    public ResetPasswordService(
            PasswordResetTokenRepository resets,
            RefreshTokenRepository refreshes,
            PasswordEncoder passwords,
            AuditService audit) {
        this.resets = resets;
        this.refreshes = refreshes;
        this.passwords = passwords;
        this.audit = audit;
    }

    @Transactional
    public ResetPasswordResponse redeem(ResetPasswordRequest request, HttpServletRequest http) {
        String hash = HashUtil.sha256(request.token().trim());

        PasswordResetToken stored = resets
                .findByTokenHashAndUsedFalseAndExpiresAtAfter(hash, Instant.now())
                .orElse(null);

        if (stored == null) {
            audit.record("PASSWORD_RESET_FAILED", "AUTH", null,
                    null, "{\"reason\":\"invalid_or_expired_token\"}", http);
            log.warn("Password reset rejected: token invalid, used or expired");
            throw new InvalidResetTokenException();
        }

        Admin admin = stored.getAdmin();

        // A disabled account must not be able to change its password via a link.
        if (!admin.isEnabled()) {
            audit.record("PASSWORD_RESET_FAILED", "AUTH", String.valueOf(admin.getId()),
                    null, "{\"reason\":\"account_disabled\"}", http);
            log.warn("Password reset rejected for disabled admin {}", admin.getId());
            throw new InvalidResetTokenException();
        }

        admin.setPasswordHash(passwords.encode(request.newPassword()));
        admin.setFailedAttempts(0);
        admin.setLockedUntil(null);

        stored.setUsed(true);

        // Kill every existing refresh session: all devices must sign in again.
        refreshes.revokeAllFor(admin, Instant.now());

        audit.record("PASSWORD_RESET_COMPLETED", "AUTH", String.valueOf(admin.getId()),
                null, "{\"email\":\"" + admin.getEmail() + "\"}", http);
        log.info("Password reset completed for admin {}", admin.getId());

        return ResetPasswordResponse.ok();
    }
}
