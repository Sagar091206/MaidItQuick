package com.maiditquick.admin.escalations;

import com.maiditquick.admin.bookings.Booking;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;

@Entity
@Table(name = "disputes")
@Getter
@Setter
@NoArgsConstructor
public class Dispute {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "booking_id")
  private Booking booking;
  @Column(name = "reporter_type", nullable = false, length = 20)
  private String reporterType = "CUSTOMER";
  @Column(nullable = false, length = 160)
  private String subject;
  @Column(length = 2000)
  private String description;
  @Column(nullable = false)
  private String status = "OPEN";
  @Column(name = "log_path", length = 500)
  private String logPath;
  @Column(length = 2000)
  private String resolution;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
  @Column(name = "resolved_at")
  private Instant resolvedAt;
  @Column(name = "resolved_by_admin_id")
  private Long resolvedByAdminId;
}
