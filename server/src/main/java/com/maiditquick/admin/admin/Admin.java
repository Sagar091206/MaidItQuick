package com.maiditquick.admin.admin;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;

@Entity @Table(name = "admins") @Getter @Setter @NoArgsConstructor
public class Admin {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
  @Column(nullable = false, unique = true) private String email;
  @Column(name = "password_hash", nullable = false) private String passwordHash;
  @Column(name = "display_name", nullable = false) private String displayName;
  @Column(nullable = false) private boolean enabled = true;
  @Column(name = "locked_until") private Instant lockedUntil;
  @Column(name = "failed_attempts", nullable = false) private int failedAttempts;
  @Column(name = "last_login") private Instant lastLogin;
  @ManyToOne(fetch = FetchType.EAGER) @JoinColumn(name = "role_id", nullable = false) private AdminRole role;
}
