package com.makeitquick.notification;

import com.makeitquick.security.UserAccount;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class NotificationService {
    private final NotificationRepository notifications;
    private final ObjectProvider<JavaMailSender> mailSender;
    private final boolean emailEnabled;
    private final String fromAddress;

    NotificationService(
            NotificationRepository notifications,
            ObjectProvider<JavaMailSender> mailSender,
            @Value("${app.mail.enabled:false}") boolean emailEnabled,
            @Value("${app.mail.from:no-reply@makeitquick.local}") String fromAddress) {
        this.notifications = notifications;
        this.mailSender = mailSender;
        this.emailEnabled = emailEnabled;
        this.fromAddress = fromAddress;
    }

    public void send(UserAccount recipient, NotificationType type, String title, String message) {
        notifications.save(new AppNotification(recipient, type, title, message));
        if (emailEnabled && recipient.isEmailNotifications() && hasDeliverableEmail(recipient)
                && mailSender.getIfAvailable() != null) {
            try {
                SimpleMailMessage email = new SimpleMailMessage();
                email.setFrom(fromAddress);
                email.setTo(recipient.getEmail());
                email.setSubject(title);
                email.setText(message);
                mailSender.getIfAvailable().send(email);
            } catch (RuntimeException ignored) {
                // The in-app notification is already saved; delivery failures can be retried later.
            }
        }
    }

    private boolean hasDeliverableEmail(UserAccount recipient) {
        return recipient.getEmail() != null && !recipient.getEmail().isBlank();
    }
}
