package com.makeitquick.notification;

import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import java.util.HashMap;
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
    private final SessionResolver resolver;
    private final UserRepository users;

    NotificationController(NotificationRepository notifications, SessionResolver resolver, UserRepository users) {
        this.notifications = notifications;
        this.resolver = resolver;
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

    @PostMapping("/read-all")
    public Map<String, Object> markAllRead(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        UserAccount user = requireUser(authorization);
        List<AppNotification> unread = notifications.findByRecipientAndReadFalse(user);
        unread.forEach(AppNotification::markRead);
        notifications.saveAll(unread);
        return Map.of("marked", unread.size());
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
        return resolver.fromBearer(authorization)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
    }

    private Map<String, Object> view(AppNotification notification) {
        Map<String, Object> result = new HashMap<>();
        result.put("id", notification.getId());
        result.put("type", notification.getType());
        result.put("title", notification.getTitle());
        result.put("message", notification.getMessage());
        result.put("read", notification.isRead());
        result.put("createdAt", notification.getCreatedAt());
        result.put("bookingId", notification.getBookingId());
        return result;
    }

    record PreferenceInput(boolean emailNotifications) {}
}
