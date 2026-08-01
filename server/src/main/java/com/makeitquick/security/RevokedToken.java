package com.makeitquick.security;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * Revoked signed tokens (JWTs) whose user signed out.
 *
 * <p>Stores a SHA-256 hash of the token rather than the token itself so a
 * database breach cannot replay credentials. Rows expire with the token they
 * reference and are purged by a periodic sweep.</p>
 */
@Entity
@Table(name = "revoked_tokens", indexes = {
        @Index(name = "idx_revoked_tokens_hash", columnList = "token_hash", unique = true),
        @Index(name = "idx_revoked_tokens_expiry", columnList = "expires_at")
})
public class RevokedToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "token_hash", nullable = false, length = 64)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    protected RevokedToken() {
    }

    public RevokedToken(String tokenHash, Instant expiresAt) {
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
    }

    public Long getId() {
        return id;
    }

    public String getTokenHash() {
        return tokenHash;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }
}
