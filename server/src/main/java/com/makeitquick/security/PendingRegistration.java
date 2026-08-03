package com.makeitquick.security;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * One-time token issued after a successful OTP verification for a phone that
 * has no customer account yet. It binds the later profile completion request
 * to the verified phone number and cannot be reused.
 */
@Entity
@Table(name = "pending_registrations")
public class PendingRegistration {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String phone;

    @Column(nullable = false, unique = true, length = 128)
    private String token;

    @Column(nullable = false)
    private Instant expiresAt;

    @Column(nullable = false)
    private boolean used;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected PendingRegistration() {}

    PendingRegistration(String phone, String token, Instant expiresAt) {
        this.phone = phone;
        this.token = token;
        this.expiresAt = expiresAt;
    }

    public Long getId() { return id; }
    public String getPhone() { return phone; }
    public String getToken() { return token; }
    public Instant getExpiresAt() { return expiresAt; }
    public boolean isUsed() { return used; }

    public boolean valid() {
        return !used && expiresAt.isAfter(Instant.now());
    }

    public void consume() {
        used = true;
    }
}
