package com.makeitquick.security;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class UserAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(unique = true)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    @Column(nullable = false, unique = true)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    @Column(nullable = false)
    private boolean enabled = true;

    @Column(nullable = false)
    private boolean emailNotifications = true;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected UserAccount() {
    }

    public UserAccount(String name, String email, String passwordHash, Role role) {
        this(name, email, passwordHash, placeholderPhone(), role);
    }

    public UserAccount(
            String name,
            String email,
            String passwordHash,
            String phone,
            Role role
    ) {
        this.name = name;
        this.email = normalizeEmail(email);
        this.passwordHash = passwordHash;
        this.phone = normalizePhone(phone);
        this.role = role;
    }

    @PrePersist
    @PreUpdate
    void normalizeContactFields() {
        email = normalizeEmail(email);
        phone = normalizePhone(phone);
    }

    private static String normalizeEmail(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }

        return value.trim().toLowerCase();
    }

    private static String normalizePhone(String value) {
        if (value == null || value.isBlank()) {
            return placeholderPhone();
        }

        return value.trim();
    }

    private static String placeholderPhone() {
        return "UNSET-" + UUID.randomUUID();
    }

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getPhone() {
        return phone;
    }

    public Role getRole() {
        return role;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public boolean isEmailNotifications() {
        return emailNotifications;
    }

    public void setPasswordHash(String value) {
        passwordHash = value;
    }

    public void disable() {
        enabled = false;
    }

    public void setEmailNotifications(boolean value) {
        emailNotifications = value;
    }
}