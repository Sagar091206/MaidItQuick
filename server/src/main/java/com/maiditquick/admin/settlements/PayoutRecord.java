package com.maiditquick.admin.settlements;

import com.makeitquick.security.UserAccount;
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "payout_records")
@Getter
@Setter
@NoArgsConstructor
public class PayoutRecord {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @ManyToOne(fetch = FetchType.EAGER, optional = false)
  @JoinColumn(name = "worker_id")
  private UserAccount worker;
  @Column(name = "period_label", nullable = false, length = 40)
  private String periodLabel;
  @Column(nullable = false)
  private BigDecimal amount = BigDecimal.ZERO;
  @Column(nullable = false)
  private String status = "PENDING";
  @Column(name = "transaction_ref", length = 64)
  private String transactionRef;
  @Column(name = "paid_at")
  private Instant paidAt;
  @Column(name = "paid_by_admin_id")
  private Long paidByAdminId;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
}
