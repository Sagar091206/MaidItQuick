package com.maiditquick.admin.auth;

import com.maiditquick.admin.admin.Admin;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

/**
 * Password reset token (US 1.2).
 * Only the SHA-256 hash of the token is persisted — never the raw value.
 * Tokens expire after 15 minutes and are invalidated (used = true) as soon
 * as a newer reset token is issued for the same admin.
 */
@Entity
@Table(name = "password_reset_tokens", indexes = {
        @Index(name = "idx_prt_admin_id", columnList = "admin_id"),
        @Index(name = "idx_prt_token_hash", columnList = "token_hash"),
        @Index(name = "idx_prt_expires_at", columnList = "expires_at")
})
@Getter
@Setter
@NoArgsConstructor
public class PasswordResetToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "admin_id", nullable = false)
    private Admin admin;

    @Column(name = "token_hash", nullable = false, unique = true)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(nullable = false)
    private boolean used;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();
}
