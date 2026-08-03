package com.maiditquick.admin.payments;

import com.maiditquick.admin.bookings.Booking;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import java.math.BigDecimal;
import java.time.Instant;

@Entity(name = "AdminPayment")
@Table(name = "admin_payments")
@Getter
@Setter
@NoArgsConstructor
public class Payment {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "booking_id")
  @OnDelete(action = OnDeleteAction.SET_NULL)
  private Booking booking;
  @Column(nullable = false)
  private BigDecimal amount = BigDecimal.ZERO;
  @Column(nullable = false)
  private String method = "CASH";
  @Column(nullable = false)
  private String status = "PENDING";
  @Column(name = "transaction_id", length = 128)
  private String transactionId;
  @Column(name = "paid_at")
  private Instant paidAt;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
}
