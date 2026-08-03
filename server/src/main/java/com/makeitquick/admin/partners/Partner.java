package com.makeitquick.admin.partners;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnDefault;
import java.time.Instant;

@Entity
@Table(name = "partners")
@Getter
@Setter
@NoArgsConstructor
public class Partner {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @Column(name = "source_user_id", unique = true)
  private Long sourceUserId;
  @Column(nullable = false, length = 160)
  private String name;
  @Column(nullable = false, unique = true, length = 40)
  private String phone;
  @Column(length = 255)
  private String email;
  @Column(length = 500)
  private String address;
  @Column(name = "kyc_status", nullable = false)
  private String kycStatus = "PENDING";
  @Column(name = "account_status", nullable = false)
  @ColumnDefault("'ACTIVE'")
  private String accountStatus = "ACTIVE";
  @Column(name = "suspended_at")
  private Instant suspendedAt;
  @Column(name = "deleted_at")
  private Instant deletedAt;
  @Column(name = "rejection_reason", length = 1000)
  private String rejectionReason;
  @Column(name = "registered_at", nullable = false, updatable = false)
  private Instant registeredAt = Instant.now();
  @Column(name = "approved_at")
  private Instant approvedAt;
  @Column(name = "identity_doc_type")
  private String identityDocType = "AADHAAR";
  @Column(name = "identity_doc_path", length = 500)
  private String identityDocPath;
  @Column(name = "address_doc_path", length = 500)
  private String addressDocPath;
  @Column(name = "pan_doc_path", length = 500)
  private String panDocPath;
  @Column(name = "pan_number", length = 20)
  private String panNumber;
  @Column(name = "pan_name", length = 160)
  private String panName;
  @Column(name = "bank_account_holder", length = 160)
  private String bankAccountHolder;
  @Column(name = "bank_account_number", length = 40)
  private String bankAccountNumber;
  @Column(name = "bank_ifsc", length = 20)
  private String bankIfsc;
  @Column(name = "upi_id", length = 80)
  private String upiId;
  @Column(name = "payout_status", nullable = false)
  private String payoutStatus = "NOT_SUBMITTED";
  private Double latitude;
  private Double longitude;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
  @Column(name = "updated_at")
  private Instant updatedAt;
}
