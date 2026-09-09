package com.makeitquick.admin.returns;

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

  @Column(length = 50)
  private String faultType;

  @Column(length = 50)
  private String severity;

  @Column(name = "service_delivered_percent")
  private Integer serviceDeliveredPercent;

  @Column(length = 50)
  private String recommendedResolution;

  @Column(name = "recommended_refund_percentage")
  private Integer recommendedRefundPercentage;

  @Column(name = "recommended_refund_amount_paise")
  private Integer recommendedRefundAmountPaise;

  @Column(length = 1000)
  private String recommendationReason;

  @Column(name = "evidence_required")
  private Boolean evidenceRequired = false;

  public Boolean getEvidenceRequired() {
    return Boolean.TRUE.equals(evidenceRequired);
  }

  public boolean isEvidenceRequired() {
    return Boolean.TRUE.equals(evidenceRequired);
  }

  @Column(name = "system_recommendation_at")
  private Instant systemRecommendationAt;

  @Column(name = "approved_amount", precision = 10, scale = 2)
  private BigDecimal approvedAmount;

  @Column(name = "decided_by", length = 100)
  private String decidedBy;

  @Column(name = "cancellation_stage", length = 50)
  private String cancellationStage;

  @Column(name = "cancellation_reason", length = 255)
  private String cancellationReason;
}
