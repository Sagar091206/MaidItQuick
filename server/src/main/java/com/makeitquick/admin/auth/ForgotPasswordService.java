package com.makeitquick.admin.auth;

import com.makeitquick.security.ResetToken;
import com.makeitquick.security.ResetTokenRepository;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.auth.AuthExceptions.PasswordResetMailException;
import com.makeitquick.admin.common.TokenGenerator;
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
 * Forgot-password flow: normalize email -> find the admin account (never
 * revealing existence) -> if active, generate a 64-char secure token, invalidate
 * older tokens, send the reset email and write an audit entry. Unknown or
 * disabled accounts still receive the generic success response.
 */
@Service
public class ForgotPasswordService {

    private static final Logger log = LoggerFactory.getLogger(ForgotPasswordService.class);
    private static final Duration TOKEN_TTL = Duration.ofMinutes(15);

    private final UserRepository users;
    private final ResetTokenRepository resets;
    private final TokenGenerator tokens;
    private final JavaMailSender mail;
    private final AuditService audit;
    private final String resetUrlBase;

    public ForgotPasswordService(
            UserRepository users,
            ResetTokenRepository resets,
            TokenGenerator tokens,
            JavaMailSender mail,
            AuditService audit,
            @Value("${app.mail.reset-url}") String resetUrlBase) {
        this.users = users;
        this.resets = resets;
        this.tokens = tokens;
        this.mail = mail;
        this.audit = audit;
        this.resetUrlBase = resetUrlBase;
    }

    @Transactional
    public ForgotPasswordResponse requestReset(ForgotPasswordRequest request, HttpServletRequest http) {
        String email = normalize(request.email());

        UserAccount user = users.findByEmailIgnoreCase(email)
                .filter(u -> u.getRole() == Role.ADMIN)
                .orElse(null);

        // Unknown or inactive account: audit + log, but respond exactly like a success.
        if (user == null || !user.isEnabled()) {
            audit.record("FORGOT_PASSWORD_REQUESTED", "AUTH",
                    user == null ? null : String.valueOf(user.getId()),
                    null, "{\"email\":\"" + email + "\",\"status\":\"NO_EMAIL_SENT\"}", http);
            log.info("Password reset requested for email without an active account");
            return ForgotPasswordResponse.generic();
        }

        String rawToken = tokens.generate();

        // Invalidate every previous active token so only the newest one works.
        resets.markAllUsedFor(user);

        ResetToken stored = resets.save(new ResetToken(rawToken, user, Instant.now().plus(TOKEN_TTL)));

        log.info("Password reset token created for user {}", user.getId());

        try {
            sendResetEmail(user, rawToken);
        } catch (MailException | MessagingException e) {
            log.error("Password reset email failed for user {}", user.getId(), e);
            audit.record("FORGOT_PASSWORD_REQUESTED", "AUTH", String.valueOf(user.getId()),
                    null, "{\"email\":\"" + email + "\",\"status\":\"EMAIL_FAILED\"}", http);
            throw new PasswordResetMailException();
        }

        log.info("Password reset email sent to user {}", user.getId());
        audit.record("FORGOT_PASSWORD_REQUESTED", "AUTH", String.valueOf(user.getId()),
                null, "{\"email\":\"" + email + "\",\"status\":\"EMAIL_SENT\"}", http);

        return ForgotPasswordResponse.generic();
    }

    private void sendResetEmail(UserAccount user, String rawToken) throws MessagingException {
        MimeMessage message = mail.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, false, StandardCharsets.UTF_8.name());

        helper.setTo(user.getEmail());
        helper.setSubject("Reset Your MaidItQuick Admin Password");

        String body = "Hello " + user.getName() + "\n\n"
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
