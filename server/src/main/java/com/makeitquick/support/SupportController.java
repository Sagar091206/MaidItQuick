package com.makeitquick.support;

import com.makeitquick.admin.returns.ReturnRepository;
import com.makeitquick.admin.returns.ReturnRequest;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/support")
@CrossOrigin(origins = "*")
public class SupportController {
    private final SupportTicketRepository tickets;
    private final SupportMessageRepository messages;
    private final SessionResolver resolver;
    private final NotificationService notifications;
    private final SupportRulesEngine rulesEngine;
    private final ReturnRepository returnRepository;
    private final BookingRepository bookingRepository;
    private final String uploadsDir;

    public SupportController(
            SupportTicketRepository tickets,
            SupportMessageRepository messages,
            SessionResolver resolver,
            NotificationService notifications) {
        this(tickets, messages, resolver, notifications, new SupportRulesEngine(), null, null, "uploads");
    }

    @Autowired
    public SupportController(
            SupportTicketRepository tickets,
            SupportMessageRepository messages,
            SessionResolver resolver,
            NotificationService notifications,
            SupportRulesEngine rulesEngine,
            @Autowired(required = false) ReturnRepository returnRepository,
            @Autowired(required = false) BookingRepository bookingRepository,
            @Value("${app.uploads-dir:uploads}") String uploadsDir) {
        this.tickets = tickets;
        this.messages = messages;
        this.resolver = resolver;
        this.notifications = notifications;
        this.rulesEngine = rulesEngine != null ? rulesEngine : new SupportRulesEngine();
        this.returnRepository = returnRepository;
        this.bookingRepository = bookingRepository;
        this.uploadsDir = uploadsDir != null ? uploadsDir : "uploads";
    }

    @GetMapping("/scenarios")
    public List<SupportRulesEngine.ScenarioRule> scenarios() {
        return rulesEngine.getAllRules();
    }

    @PostMapping(value = "/evidence", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Map<String, Object> uploadEvidence(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam("file") MultipartFile file) {
        requireUser(authorization);
        if (file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Evidence file cannot be empty");
        }
        try {
            Path uploadPath = Paths.get(uploadsDir).toAbsolutePath().normalize().resolve("support");
            Files.createDirectories(uploadPath);
            String original = file.getOriginalFilename() == null ? "evidence" : file.getOriginalFilename();
            String ext = original.contains(".") ? original.substring(original.lastIndexOf('.')).toLowerCase() : ".jpg";
            if (ext.length() > 10) ext = ".jpg";
            String name = "evidence-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8) + ext;
            Path target = uploadPath.resolve(name);
            file.transferTo(target);
            return Map.of(
                "url", "/uploads/support/" + name,
                "fileName", original,
                "size", file.getSize()
            );
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to store evidence file: " + e.getMessage());
        }
    }

    @PostMapping("/tickets")
    public Map<String, Object> create(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody TicketInput input) {
        UserAccount requester = requireUser(authorization);
        String cat = input.category() != null && !input.category().isBlank() ? input.category().trim() : null;

        SupportTicket ticket = new SupportTicket(
            requester,
            input.subject(),
            input.message(),
            cat,
            input.bookingId()
        );

        if (input.scenario() != null && !input.scenario().isBlank()) {
            SupportRulesEngine.ScenarioRule rule = rulesEngine.evaluate(input.scenario());
            ticket.setScenario(rule.scenario());
            ticket.setPriority(rule.priority());
            ticket.setSeverity(rule.severity());
            ticket.setRecommendedAction(rule.recommendedAction());
            ticket.setRequiresAdminReview(rule.requiresAdminReview());
            ticket.setConnectsToRefund(rule.connectsToRefund());
            if (cat == null) {
                ticket.setCategory(rule.category());
            }

            if (rule.requiresEvidence()) {
                if (input.evidenceUrls() == null || input.evidenceUrls().isEmpty()) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "Photographic evidence is required for: " + rule.displayName());
                }
            }
        }

        if (input.evidenceUrls() != null && !input.evidenceUrls().isEmpty()) {
            ticket.setEvidenceList(input.evidenceUrls());
        }

        ticket = tickets.save(ticket);
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
        messages.save(new SupportMessage(ticket, Role.ADMIN, input.message()));
        notifications.send(ticket.getRequester(), NotificationType.OPERATIONS, "Support replied", input.message());
        return view(ticket);
    }

    @GetMapping("/tickets/{id}/messages")
    public List<Map<String, Object>> conversation(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        UserAccount user = requireUser(authorization);
        SupportTicket ticket = getTicket(id);
        if (user.getRole() != Role.ADMIN && !ticket.getRequester().getId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not permitted");
        }
        return messages.findByTicket_IdOrderByCreatedAtAsc(id).stream().map(this::messageView).toList();
    }

    @PostMapping("/tickets/{id}/messages")
    public Map<String, Object> sendMessage(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id,
            @Valid @RequestBody ReplyInput input) {
        UserAccount user = requireUser(authorization);
        SupportTicket ticket = getTicket(id);
        if (user.getRole() == Role.ADMIN) return reply(authorization, id, input);
        if (!ticket.getRequester().getId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not permitted");
        }
        ticket.setStatus(TicketStatus.IN_PROGRESS);
        tickets.save(ticket);
        SupportMessage saved = messages.save(new SupportMessage(ticket, user.getRole(), input.message()));
        return messageView(saved);
    }

    @PostMapping("/tickets/{id}/connect-refund")
    public Map<String, Object> connectRefund(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        requireAdmin(authorization);
        SupportTicket ticket = getTicket(id);
        if (ticket.getBookingId() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Ticket does not have an associated booking");
        }
        if (returnRepository == null || bookingRepository == null) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Refund service not available");
        }

        ReturnRequest returnReq = returnRepository.findTopByBookingIdOrderByCreatedAtDesc(ticket.getBookingId()).orElseGet(() -> {
            Booking booking = bookingRepository.findById(ticket.getBookingId())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found"));
            ReturnRequest req = new ReturnRequest();
            req.setBookingId(booking.getId());
            BigDecimal amount = booking.getTotalAmount() != null && booking.getTotalAmount().compareTo(BigDecimal.ZERO) > 0
                    ? booking.getTotalAmount()
                    : BigDecimal.valueOf(booking.getPaymentAmountPaise() != null ? booking.getPaymentAmountPaise() / 100.0 : 0.0);
            req.setRequestedAmount(amount);
            req.setReason("[Support Ticket #" + ticket.getId() + "] " + ticket.getSubject() + ": " + ticket.getMessage());
            req.setStatus("REQUESTED");
            req.setSeverity(ticket.getSeverity() != null ? ticket.getSeverity() : "MEDIUM");
            req.setRecommendedResolution(ticket.getRecommendedAction() != null ? ticket.getRecommendedAction() : "Investigation");
            return returnRepository.save(req);
        });

        ticket.setConnectsToRefund(true);
        tickets.save(ticket);

        return Map.of(
            "success", true,
            "returnId", returnReq.getId(),
            "status", returnReq.getStatus(),
            "requestedAmount", returnReq.getRequestedAmount()
        );
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
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", ticket.getId());
        map.put("subject", ticket.getSubject());
        map.put("message", ticket.getMessage());
        map.put("reply", ticket.getAdminReply() == null ? "" : ticket.getAdminReply());
        map.put("status", ticket.getStatus());
        map.put("requester", ticket.getRequester().getName());
        map.put("requesterRole", ticket.getRequester().getRole());
        map.put("createdAt", ticket.getCreatedAt());
        map.put("updatedAt", ticket.getUpdatedAt() != null ? ticket.getUpdatedAt() : ticket.getCreatedAt());

        if (ticket.getCategory() != null) {
            map.put("category", ticket.getCategory());
        }
        if (ticket.getBookingId() != null) {
            map.put("bookingId", ticket.getBookingId());
        }
        if (ticket.getScenario() != null) {
            map.put("scenario", ticket.getScenario());
        }
        if (ticket.getPriority() != null) {
            map.put("priority", ticket.getPriority());
        }
        if (ticket.getSeverity() != null) {
            map.put("severity", ticket.getSeverity());
        }
        if (ticket.getRecommendedAction() != null) {
            map.put("recommendedAction", ticket.getRecommendedAction());
        }
        map.put("requiresAdminReview", ticket.getRequiresAdminReview());
        map.put("connectsToRefund", ticket.getConnectsToRefund());
        if (ticket.getEvidenceUrls() != null) {
            map.put("evidenceUrls", ticket.getEvidenceUrls());
        }
        map.put("evidenceList", ticket.getEvidenceList());

        if (ticket.getBookingId() != null && returnRepository != null) {
            returnRepository.findTopByBookingIdOrderByCreatedAtDesc(ticket.getBookingId()).ifPresent(ret -> {
                Map<String, Object> refundMap = new LinkedHashMap<>();
                refundMap.put("id", ret.getId());
                refundMap.put("status", ret.getStatus());
                refundMap.put("requestedAmount", ret.getRequestedAmount());
                refundMap.put("approvedAmount", ret.getApprovedAmount() != null ? ret.getApprovedAmount() : BigDecimal.ZERO);
                refundMap.put("reason", ret.getReason() != null ? ret.getReason() : "");
                refundMap.put("cancellationReason", ret.getCancellationReason() != null ? ret.getCancellationReason() : "");
                map.put("refundInfo", refundMap);
            });
        }

        return map;
    }

    private Map<String, Object> messageView(SupportMessage message) {
        return Map.of("id", message.getId(), "senderRole", message.getSenderRole(),
                "message", message.getMessage(), "createdAt", message.getCreatedAt());
    }

    public record TicketInput(
        @NotBlank String subject,
        @NotBlank String message,
        String category,
        Long bookingId,
        String scenario,
        List<String> evidenceUrls
    ) {
        public TicketInput(@NotBlank String subject, @NotBlank String message, String category, Long bookingId) {
            this(subject, message, category, bookingId, null, null);
        }
    }

    public record ReplyInput(@NotBlank String message) {}
    public record StatusInput(TicketStatus status) {}
}
