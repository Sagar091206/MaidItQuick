package com.maiditquick.admin.bookings;

import com.maiditquick.admin.customers.Customer;
import com.maiditquick.admin.partners.Partner;
import com.maiditquick.admin.services.ServiceOffering;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;

@Entity
@Table(name = "bookings")
@Getter
@Setter
@NoArgsConstructor
public class Booking {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "customer_id")
  @OnDelete(action = OnDeleteAction.SET_NULL)
  private Customer customer;
  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "service_id")
  @OnDelete(action = OnDeleteAction.SET_NULL)
  private ServiceOffering service;
  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "partner_id")
  @OnDelete(action = OnDeleteAction.SET_NULL)
  private Partner partner;
  private Double latitude;
  private Double longitude;
  @Column(name = "started_at")
  private Instant startedAt;
  @Column(name = "completed_at")
  private Instant completedAt;
  @Column(nullable = false)
  private String status = "PENDING";
  @Column(name = "scheduled_at")
  private LocalDateTime scheduledAt;
  @Column(length = 500)
  private String address;
  @Column(length = 1000)
  private String notes;
  @Column(nullable = false)
  private BigDecimal totalAmount = BigDecimal.ZERO;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
  @Column(name = "updated_at")
  private Instant updatedAt;
}
