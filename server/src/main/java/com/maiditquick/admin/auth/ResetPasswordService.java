package com.maiditquick.admin.auth;

import com.makeitquick.security.ResetToken;
import com.makeitquick.security.ResetTokenRepository;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.auth.AuthExceptions.InvalidResetTokenException;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Reset-password flow. The emailed token is redeemed here: it must exist, be
 * unused and unexpired. On success the admin password is re-hashed (BCrypt),
 * the token is consumed (single use), every refresh session is revoked so all
 * devices must sign in again, and the account lock is cleared. Any unusable
 * token fails with the same generic 400 — no information leak.
 */
@Service
public class ResetPasswordService {

    private static final Logger log = LoggerFactory.getLogger(ResetPasswordService.class);

    private final ResetTokenRepository resets;
    private final RefreshTokenRepository refreshes;
    private final UserRepository users;
    private final PasswordEncoder passwords;
    private final AuditService audit;

    public ResetPasswordService(
            ResetTokenRepository resets,
            RefreshTokenRepository refreshes,
            UserRepository users,
            PasswordEncoder passwords,
            AuditService audit) {
        this.resets = resets;
        this.refreshes = refreshes;
        this.users = users;
        this.passwords = passwords;
        this.audit = audit;
    }

    @Transactional
    public ResetPasswordResponse redeem(ResetPasswordRequest request, HttpServletRequest http) {
        ResetToken stored = resets.findByToken(request.token().trim())
                .filter(ResetToken::valid)
                .orElse(null);

        if (stored == null) {
            audit.record("PASSWORD_RESET_FAILED", "AUTH", null,
                    null, "{\"reason\":\"invalid_or_expired_token\"}", http);
            log.warn("Password reset rejected: token invalid, used or expired");
            throw new InvalidResetTokenException();
        }

        UserAccount user = stored.getUser();

        // A disabled account must not be able to change its password via a link.
        if (!user.isEnabled()) {
            audit.record("PASSWORD_RESET_FAILED", "AUTH", String.valueOf(user.getId()),
                    null, "{\"reason\":\"account_disabled\"}", http);
            log.warn("Password reset rejected for disabled user {}", user.getId());
            throw new InvalidResetTokenException();
        }

        user.setPasswordHash(passwords.encode(request.newPassword()));
        user.setFailedAttempts(0);
        user.setLockedUntil(null);

        stored.use();

        // Kill every existing refresh session: all devices must sign in again.
        refreshes.revokeAllFor(user, Instant.now());
        users.save(user);
        resets.save(stored);

        audit.record("PASSWORD_RESET_COMPLETED", "AUTH", String.valueOf(user.getId()),
                null, "{\"email\":\"" + user.getEmail() + "\"}", http);
        log.info("Password reset completed for user {}", user.getId());

        return ResetPasswordResponse.ok();
    }
}
