package com.makeitquick.support;

import com.makeitquick.security.Role;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "support_messages")
public class SupportMessage {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false) private SupportTicket ticket;
    @Enumerated(EnumType.STRING) @Column(nullable = false) private Role senderRole;
    @Column(nullable = false, length = 2000) private String message;
    @Column(nullable = false, updatable = false) private Instant createdAt = Instant.now();

    protected SupportMessage() {}
    SupportMessage(SupportTicket ticket, Role senderRole, String message) {
        this.ticket = ticket; this.senderRole = senderRole; this.message = message;
    }
    public Long getId() { return id; }
    public Role getSenderRole() { return senderRole; }
    public String getMessage() { return message; }
    public Instant getCreatedAt() { return createdAt; }
}
