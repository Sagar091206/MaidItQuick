package com.makeitquick.security;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Lob;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

@Entity
@Table(
        name = "users",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_users_phone_role",
                columnNames = {"phone", "role"}
        )
)
public class UserAccount {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String email = "";

    @Column(nullable = false)
    private String passwordHash;

    @Column(nullable = false)
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

    private String gender;

    private LocalDate dob;

    @Lob
    private String profileImage;

    private Boolean profileCompleted;

    protected UserAccount() {
    }

    public UserAccount(String name, String email, String passwordHash, Role role) {
        this(name, email, passwordHash, placeholderPhone(), role);
    }

    public UserAccount(String name, String email, String passwordHash, String phone, Role role) {
        this.name = name;
        this.email = normalizeEmail(email);
        this.passwordHash = passwordHash;
        this.phone = normalizePhone(phone);
        this.role = role;
    }

    @PrePersist
    @PreUpdate
    void ensureRequiredContactFields() {
        email = normalizeEmail(email);
        phone = normalizePhone(phone);
    }

    private static String normalizeEmail(String value) {
        if (value == null || value.isBlank()) {
            return "";
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

    public String getGender() {
        return gender == null ? "" : gender;
    }

    public LocalDate getDob() {
        return dob;
    }

    public String getProfileImage() {
        return profileImage == null ? "" : profileImage;
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

    public void setName(String value) {
        name = value;
    }

    public void setEmail(String value) {
        email = normalizeEmail(value);
    }

    public void setGender(String value) {
        gender = value;
    }

    public void setDob(LocalDate value) {
        dob = value;
    }

    public void setProfileImage(String value) {
        profileImage = value == null ? "" : value;
    }

    public void setProfileCompleted(boolean value) {
        profileCompleted = value;
    }

    public boolean profileComplete() {
        return profileCompleted == null ? name != null && !name.isBlank() : profileCompleted;
    }
}
