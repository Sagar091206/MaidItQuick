package com.makeitquick.support;

import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/support")
@CrossOrigin(origins = "*")
public class SupportController {
    private final SupportTicketRepository tickets;
    private final SessionResolver resolver;
    private final NotificationService notifications;

    SupportController(SupportTicketRepository tickets, SessionResolver resolver, NotificationService notifications) {
        this.tickets = tickets;
        this.resolver = resolver;
        this.notifications = notifications;
    }

    @PostMapping("/tickets")
    public Map<String, Object> create(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody TicketInput input) {
        SupportTicket ticket = tickets.save(new SupportTicket(requireUser(authorization), input.subject(), input.message()));
        return view(ticket);
    }

    @GetMapping("/tickets/mine")
    public List<Map<String, Object>> mine(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return tickets.findByRequesterOrderByIdDesc(requireUser(authorization)).stream().map(this::view).toList();
    }

    @GetMapping("/tickets")
    public List<Map<String, Object>> all(@RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdmin(authorization);
        return tickets.findAll().stream().map(this::view).toList();
    }

    @PostMapping("/tickets/{id}/status")
    public Map<String, Object> updateStatus(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id,
            @Valid @RequestBody StatusInput input) {
        requireAdmin(authorization);
        SupportTicket ticket = getTicket(id);
        ticket.setStatus(input.status());
        return view(tickets.save(ticket));
    }

    @PostMapping("/tickets/{id}/reply")
    public Map<String, Object> reply(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id,
            @Valid @RequestBody ReplyInput input) {
        requireAdmin(authorization);
        SupportTicket ticket = getTicket(id);
        ticket.reply(input.message());
        ticket = tickets.save(ticket);
        notifications.send(ticket.getRequester(), NotificationType.OPERATIONS, "Support replied", input.message());
        return view(ticket);
    }

    private UserAccount requireUser(String authorization) {
        return resolver.fromBearer(authorization)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
    }
    private void requireAdmin(String authorization) {
        if (requireUser(authorization).getRole() != Role.ADMIN) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin access required");
        }
    }
    private SupportTicket getTicket(Long id) {
        return tickets.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Support ticket not found"));
    }
    private Map<String, Object> view(SupportTicket ticket) {
        return Map.of("id", ticket.getId(), "subject", ticket.getSubject(), "message", ticket.getMessage(),
                "reply", ticket.getAdminReply() == null ? "" : ticket.getAdminReply(), "status", ticket.getStatus(),
                "requester", ticket.getRequester().getName(), "createdAt", ticket.getCreatedAt());
    }
    record TicketInput(@NotBlank String subject, @NotBlank String message) {}
    record ReplyInput(@NotBlank String message) {}
    record StatusInput(TicketStatus status) {}
}
