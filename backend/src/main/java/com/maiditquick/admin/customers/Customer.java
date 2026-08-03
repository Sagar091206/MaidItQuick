package com.maiditquick.admin.customers;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "customers")
@Getter
@Setter
@NoArgsConstructor
public class Customer {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @Column(nullable = false)
  private String name;
  @Column(nullable = false, unique = true)
  private String email;
  private String phone;
  private String address;
  @Column(nullable = false)
  private String status = "ACTIVE";
  @Column(name = "wallet_balance", nullable = false)
  private BigDecimal walletBalance = BigDecimal.ZERO;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
  @Column(name = "updated_at")
  private Instant updatedAt;
  @Column(name = "deleted_at")
  private Instant deletedAt;
}
