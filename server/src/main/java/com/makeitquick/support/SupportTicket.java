package com.makeitquick.support;

import com.makeitquick.security.UserAccount;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

@Entity
@Table(name = "support_tickets")
public class SupportTicket {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false) private UserAccount requester;
    @Column(nullable = false, length = 140) private String subject;
    @Column(nullable = false, length = 2000) private String message;
    @Column(length = 2000) private String adminReply;
    @Column(length = 60) private String category;
    @Column(name = "booking_id") private Long bookingId;

    @Column(length = 60) private String scenario;
    @Column(length = 20) private String priority;
    @Column(length = 20) private String severity;
    @Column(length = 500) private String recommendedAction;
    @Column(name = "requires_admin_review") private Boolean requiresAdminReview = false;
    @Column(name = "connects_to_refund") private Boolean connectsToRefund = false;
    @Column(columnDefinition = "TEXT") private String evidenceUrls;
    @Column private Instant updatedAt;

    @Enumerated(EnumType.STRING) @Column(nullable = false) private TicketStatus status = TicketStatus.OPEN;
    @Column(nullable = false, updatable = false) private Instant createdAt = Instant.now();

    protected SupportTicket() {}

    public SupportTicket(UserAccount requester, String subject, String message) {
        this(requester, subject, message, null, null);
    }

    public SupportTicket(UserAccount requester, String subject, String message, String category, Long bookingId) {
        this.requester = requester;
        this.subject = subject;
        this.message = message;
        this.category = category;
        this.bookingId = bookingId;
        this.updatedAt = Instant.now();
    }

    public Long getId() { return id; }
    public UserAccount getRequester() { return requester; }
    public String getSubject() { return subject; }
    public String getMessage() { return message; }
    public String getAdminReply() { return adminReply; }
    public String getCategory() { return category; }
    public Long getBookingId() { return bookingId; }
    public TicketStatus getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }

    public String getScenario() { return scenario; }
    public void setScenario(String scenario) { this.scenario = scenario; }

    public String getPriority() { return priority; }
    public void setPriority(String priority) { this.priority = priority; }

    public String getSeverity() { return severity; }
    public void setSeverity(String severity) { this.severity = severity; }

    public String getRecommendedAction() { return recommendedAction; }
    public void setRecommendedAction(String recommendedAction) { this.recommendedAction = recommendedAction; }

    public Boolean getRequiresAdminReview() { return Boolean.TRUE.equals(requiresAdminReview); }
    public void setRequiresAdminReview(Boolean requiresAdminReview) { this.requiresAdminReview = requiresAdminReview; }

    public Boolean getConnectsToRefund() { return Boolean.TRUE.equals(connectsToRefund); }
    public void setConnectsToRefund(Boolean connectsToRefund) { this.connectsToRefund = connectsToRefund; }

    public String getEvidenceUrls() { return evidenceUrls; }
    public void setEvidenceUrls(String evidenceUrls) { this.evidenceUrls = evidenceUrls; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public List<String> getEvidenceList() {
        if (evidenceUrls == null || evidenceUrls.isBlank()) {
            return Collections.emptyList();
        }
        String trimmed = evidenceUrls.trim();
        if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
            trimmed = trimmed.substring(1, trimmed.length() - 1);
        }
        String[] parts = trimmed.split(",");
        List<String> list = new ArrayList<>();
        for (String p : parts) {
            String item = p.trim().replace("\"", "").replace("'", "");
            if (!item.isBlank()) {
                list.add(item);
            }
        }
        return list;
    }

    public void setEvidenceList(List<String> urls) {
        if (urls == null || urls.isEmpty()) {
            this.evidenceUrls = null;
        } else {
            this.evidenceUrls = String.join(",", urls);
        }
    }

    public void setCategory(String category) { this.category = category; }
    public void setBookingId(Long bookingId) { this.bookingId = bookingId; }
    public void setStatus(TicketStatus status) {
        this.status = status;
        this.updatedAt = Instant.now();
    }
    public void reply(String reply) {
        this.adminReply = reply;
        this.status = TicketStatus.IN_PROGRESS;
        this.updatedAt = Instant.now();
    }
}
