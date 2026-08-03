package com.makeitquick.admin.support;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;

@Entity
@Table(name = "support_requests")
@Getter
@Setter
@NoArgsConstructor
public class SupportRequest {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @Column(name = "customer_id")
  private Long customerId;
  @Column(name = "customer_name", length = 160)
  private String customerName;
  @Column(nullable = false, length = 200)
  private String subject;
  @Column(nullable = false, length = 2000)
  private String message;
  @Column(nullable = false)
  private String status = "OPEN";
  @Column(nullable = false)
  private String priority = "MEDIUM";
  @Column(nullable = false)
  private String category = "SUPPORT";
  @Column(name = "admin_reply", length = 2000)
  private String adminReply;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
  @Column(name = "resolved_at")
  private Instant resolvedAt;
  @Column(name = "updated_at")
  private Instant updatedAt;
}
