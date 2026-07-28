package com.makeitquick.notification;

import com.makeitquick.security.Session;
import com.makeitquick.security.SessionRepository;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/notifications")
@CrossOrigin(origins = "*")
public class NotificationController {
    private final NotificationRepository notifications;
    private final SessionRepository sessions;
    private final UserRepository users;

    NotificationController(NotificationRepository notifications, SessionRepository sessions, UserRepository users) {
        this.notifications = notifications;
        this.sessions = sessions;
        this.users = users;
    }

    @GetMapping
    public List<Map<String, Object>> list(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return notifications.findByRecipientOrderByCreatedAtDesc(requireUser(authorization)).stream()
                .map(this::view)
                .toList();
    }

    @PostMapping("/{id}/read")
    public Map<String, Object> markRead(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        AppNotification notification = notifications.findByIdAndRecipient(id, requireUser(authorization))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Notification not found"));
        notification.markRead();
        return view(notifications.save(notification));
    }

    @GetMapping("/preferences")
    public Map<String, Object> preferences(@RequestHeader(value = "Authorization", required = false) String authorization) {
        UserAccount user = requireUser(authorization);
        return Map.of("emailNotifications", user.isEmailNotifications());
    }

    @PostMapping("/preferences")
    public Map<String, Object> updatePreferences(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody PreferenceInput input) {
        UserAccount user = requireUser(authorization);
        user.setEmailNotifications(input.emailNotifications());
        users.save(user);
        return Map.of("emailNotifications", input.emailNotifications(), "message", "Notification preferences saved");
    }

    private UserAccount requireUser(String authorization) {
        String token = authorization == null ? "" : authorization.replaceFirst("(?i)^Bearer\\s+", "");
        return sessions.findByToken(token).filter(Session::valid).map(Session::getUser)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
    }

    private Map<String, Object> view(AppNotification notification) {
        return Map.of(
                "id", notification.getId(),
                "type", notification.getType(),
                "title", notification.getTitle(),
                "message", notification.getMessage(),
                "read", notification.isRead(),
                "createdAt", notification.getCreatedAt());
    }

    record PreferenceInput(boolean emailNotifications) {}
}
