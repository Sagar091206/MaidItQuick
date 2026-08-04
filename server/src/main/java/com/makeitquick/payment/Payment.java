package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;

/** One payment attempt (ledger record) against a booking. */
@Entity
@Table(name = "payments")
public class Payment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false) private Booking booking;
    @Column(nullable = false, length = 64) private String reference;
    @Column(nullable = false, length = 32) private String method;
    @Column(nullable = false) private int amountPaise;
    /** Compatibility column retained from the legacy payments schema. */
    @Column(name = "amount", nullable = false, precision = 12, scale = 2) private BigDecimal amount = BigDecimal.ZERO;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 32)
    private PaymentStatus status = PaymentStatus.PENDING;
    @Column(length = 500) private String gatewayResponse;
    @Column(nullable = false, updatable = false) private Instant createdAt = Instant.now();
    private Instant completedAt;

    protected Payment() {}

    public Payment(Booking booking, String reference, String method, int amountPaise) {
        this.booking = booking;
        this.reference = reference;
        this.method = method;
        this.amountPaise = amountPaise;
        this.amount = BigDecimal.valueOf(amountPaise, 2);
    }

    public Long getId() { return id; }
    public Booking getBooking() { return booking; }
    public String getReference() { return reference; }
    public String getMethod() { return method; }
    public int getAmountPaise() { return amountPaise; }
    public PaymentStatus getStatus() { return status; }
    public String getGatewayResponse() { return gatewayResponse == null ? "" : gatewayResponse; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getCompletedAt() { return completedAt; }

    public void markPaid(String gatewayResponse) {
        this.status = PaymentStatus.PAID;
        this.gatewayResponse = gatewayResponse;
        this.completedAt = Instant.now();
    }

    public void markFailed(String gatewayResponse) {
        this.status = PaymentStatus.FAILED;
        this.gatewayResponse = gatewayResponse;
        this.completedAt = Instant.now();
    }

    public void markRefunded(String gatewayResponse) {
        this.status = PaymentStatus.REFUNDED;
        this.gatewayResponse = gatewayResponse;
        this.completedAt = Instant.now();
    }

    public void setStatus(PaymentStatus value) {
        this.status = value;
    }
}
