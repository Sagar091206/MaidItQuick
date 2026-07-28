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

@Entity
@Table(name = "support_tickets")
public class SupportTicket {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false) private UserAccount requester;
    @Column(nullable = false, length = 140) private String subject;
    @Column(nullable = false, length = 2000) private String message;
    @Column(length = 2000) private String adminReply;
    @Enumerated(EnumType.STRING) @Column(nullable = false) private TicketStatus status = TicketStatus.OPEN;
    @Column(nullable = false, updatable = false) private Instant createdAt = Instant.now();
    protected SupportTicket() {}
    SupportTicket(UserAccount requester, String subject, String message) { this.requester=requester; this.subject=subject; this.message=message; }
    public Long getId(){return id;} public UserAccount getRequester(){return requester;} public String getSubject(){return subject;} public String getMessage(){return message;} public String getAdminReply(){return adminReply;} public TicketStatus getStatus(){return status;} public Instant getCreatedAt(){return createdAt;}
    public void setStatus(TicketStatus status){this.status=status;} public void reply(String reply){adminReply=reply;status=TicketStatus.IN_PROGRESS;}
}
