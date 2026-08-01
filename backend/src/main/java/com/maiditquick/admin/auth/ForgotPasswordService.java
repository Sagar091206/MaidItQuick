package com.maiditquick.admin.auth;

import com.maiditquick.admin.admin.Admin;
import com.maiditquick.admin.admin.AdminRepository;
import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.auth.AuthExceptions.PasswordResetMailException;
import com.maiditquick.admin.common.HashUtil;
import com.maiditquick.admin.common.TokenGenerator;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;

/**
 * Forgot-password flow (US 1.2):
 * normalize email -> find admin (never revealing existence) -> if active,
 * generate a 64-char secure token (SHA-256 hashed at rest, 15-minute expiry),
 * invalidate older tokens, send the reset email and write an audit entry.
 * Unknown or disabled accounts still receive the generic success response.
 */
@Service
public class ForgotPasswordService {

    private static final Logger log = LoggerFactory.getLogger(ForgotPasswordService.class);
    private static final Duration TOKEN_TTL = Duration.ofMinutes(15);

    private final AdminRepository admins;
    private final PasswordResetTokenRepository resets;
    private final TokenGenerator tokens;
    private final JavaMailSender mail;
    private final AuditService audit;
    private final String resetUrlBase;

    public ForgotPasswordService(
            AdminRepository admins,
            PasswordResetTokenRepository resets,
            TokenGenerator tokens,
            JavaMailSender mail,
            AuditService audit,
            @Value("${app.mail.reset-url}") String resetUrlBase) {
        this.admins = admins;
        this.resets = resets;
        this.tokens = tokens;
        this.mail = mail;
        this.audit = audit;
        this.resetUrlBase = resetUrlBase;
    }

    @Transactional
    public ForgotPasswordResponse requestReset(ForgotPasswordRequest request, HttpServletRequest http) {
        String email = normalize(request.email());

        Admin admin = admins.findByEmailIgnoreCase(email).orElse(null);

        // Unknown or inactive account: audit + log, but respond exactly like a success.
        if (admin == null || !admin.isEnabled()) {
            audit.record("FORGOT_PASSWORD_REQUESTED", "AUTH",
                    admin == null ? null : String.valueOf(admin.getId()),
                    null, "{\"email\":\"" + email + "\",\"status\":\"NO_EMAIL_SENT\"}", http);
            log.info("Password reset requested for email without an active account");
            return ForgotPasswordResponse.generic();
        }

        String rawToken = tokens.generate();

        // Invalidate every previous active token so only the newest one works.
        resets.markAllUsedFor(admin);

        PasswordResetToken stored = new PasswordResetToken();
        stored.setAdmin(admin);
        stored.setTokenHash(HashUtil.sha256(rawToken));
        stored.setExpiresAt(Instant.now().plus(TOKEN_TTL));
        stored.setUsed(false);
        resets.save(stored);

        log.info("Password reset token created for admin {} (expires {})", admin.getId(), stored.getExpiresAt());

        try {
            sendResetEmail(admin, rawToken);
        } catch (MailException | MessagingException e) {
            log.error("Password reset email failed for admin {}", admin.getId(), e);
            audit.record("FORGOT_PASSWORD_REQUESTED", "AUTH", String.valueOf(admin.getId()),
                    null, "{\"email\":\"" + email + "\",\"status\":\"EMAIL_FAILED\"}", http);
            throw new PasswordResetMailException();
        }

        log.info("Password reset email sent to admin {}", admin.getId());
        audit.record("FORGOT_PASSWORD_REQUESTED", "AUTH", String.valueOf(admin.getId()),
                null, "{\"email\":\"" + email + "\",\"status\":\"EMAIL_SENT\"}", http);

        return ForgotPasswordResponse.generic();
    }

    private void sendResetEmail(Admin admin, String rawToken) throws MessagingException {
        MimeMessage message = mail.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, false, StandardCharsets.UTF_8.name());

        helper.setTo(admin.getEmail());
        helper.setSubject("Reset Your MaidItQuick Admin Password");

        String body = "Hello " + admin.getDisplayName() + "\n\n"
                + "We received a request to reset your password.\n\n"
                + "Click the link below.\n"
                + resetUrlBase + "/reset-password.html?token=" + rawToken + "\n\n"
                + "This link expires in 15 minutes.\n\n"
                + "If you didn't request this, ignore this email.\n\n"
                + "Regards\n"
                + "MaidItQuick Team";

        helper.setText(body, false);

        mail.send(message);
    }

    private String normalize(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
