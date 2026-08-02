package com.maiditquick.admin.returns;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "return_requests")
@Getter
@Setter
@NoArgsConstructor
public class ReturnRequest {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @Column(name = "booking_id", nullable = false)
  private Long bookingId;
  @Column(name = "requested_amount", nullable = false, precision = 10, scale = 2)
  private BigDecimal requestedAmount;
  @Column(nullable = false, length = 1000)
  private String reason;
  @Column(nullable = false)
  private String status = "REQUESTED";
  @Column(name = "admin_note", length = 1000)
  private String adminNote;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
  @Column(name = "decided_at")
  private Instant decidedAt;
  @Column(name = "updated_at")
  private Instant updatedAt;
}
