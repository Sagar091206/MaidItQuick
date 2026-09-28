package com.makeitquick.promo;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "promo_codes")
@Getter
@Setter
@NoArgsConstructor
public class PromoCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(nullable = false)
    private int discountPercentage;

    /** Optional fixed discount amount in paise for compatibility. Null if percentage-based. */
    private Integer fixedDiscountPaise;

    @Column(nullable = false)
    private boolean enabled = true;

    @Column(length = 255)
    private String description;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at")
    private Instant updatedAt;

    public PromoCode(String code, int discountPercentage, boolean enabled, String description) {
        this(code, discountPercentage, null, enabled, description);
    }

    public PromoCode(String code, int discountPercentage, Integer fixedDiscountPaise, boolean enabled, String description) {
        this.code = code == null ? "" : code.trim().toUpperCase();
        this.discountPercentage = discountPercentage;
        this.fixedDiscountPaise = fixedDiscountPaise;
        this.enabled = enabled;
        this.description = description;
        this.createdAt = Instant.now();
    }
}
