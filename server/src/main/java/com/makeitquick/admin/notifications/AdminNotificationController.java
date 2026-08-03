package com.makeitquick.admin.notifications;

import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.common.NotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/notifications")
public class AdminNotificationController {

  private final AdminNotificationRepository notifications;
  private final AuditService audit;

  public AdminNotificationController(AdminNotificationRepository notifications, AuditService audit) {
    this.notifications = notifications;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('NOTIFICATIONS_READ')")
  public ApiResponse<List<Notification>> list() {
    return ApiResponse.ok(notifications.findAll());
  }

  @GetMapping("/unread-count")
  @PreAuthorize("hasAuthority('NOTIFICATIONS_READ')")
  public ApiResponse<Long> unreadCount() {
    return ApiResponse.ok(notifications.countByReadFalse());
  }

  @PostMapping
  @PreAuthorize("hasAuthority('NOTIFICATIONS_WRITE')")
  public ApiResponse<Notification> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    Notification n = new Notification();
    n.setTitle(body.title().trim());
    n.setMessage(body.message());
    n.setType(body.type() == null ? "INFO" : body.type());
    Notification saved = notifications.save(n);
    audit.record("NOTIFICATION_SENT", "NOTIFICATIONS", String.valueOf(saved.getId()), null,
        "{\"title\":\"" + saved.getTitle() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PatchMapping("/{id}/read")
  @PreAuthorize("hasAuthority('NOTIFICATIONS_WRITE')")
  public ApiResponse<Notification> markRead(@PathVariable long id) {
    Notification n = find(id);
    n.setRead(true);
    return ApiResponse.ok(notifications.save(n));
  }

  @PatchMapping("/read-all")
  @PreAuthorize("hasAuthority('NOTIFICATIONS_WRITE')")
  public ApiResponse<Integer> markAllRead(HttpServletRequest req) {
    int updated = notifications.markAllRead();
    audit.record("NOTIFICATIONS_MARKED_READ", "NOTIFICATIONS", null, null, "{\"count\":" + updated + "}", req);
    return ApiResponse.ok(updated);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('NOTIFICATIONS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    notifications.delete(find(id));
    audit.record("NOTIFICATION_DELETED", "NOTIFICATIONS", String.valueOf(id), null, null, req);
  }

  private Notification find(long id) {
    return notifications.findById(id).orElseThrow(() -> NotFoundException.of("Notification", id));
  }

  public record Upsert(
      @NotBlank @Size(max = 200) String title,
      @Size(max = 1000) String message,
      @Pattern(regexp = "INFO|SUCCESS|WARNING|ERROR") String type) {
  }
}
