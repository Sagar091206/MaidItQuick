package com.makeitquick.booking;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;

/** A worker declining an instant-booking request. The booking stays live for other eligible workers. */
@Entity
@Table(name = "instant_rejections", uniqueConstraints = @UniqueConstraint(columnNames = {"booking_id", "worker_id"}))
public class InstantRejection {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(nullable = false) private Long bookingId;
    @Column(nullable = false) private Long workerId;
    @Column(nullable = false, updatable = false) private Instant createdAt = Instant.now();

    protected InstantRejection() {}

    public InstantRejection(Long bookingId, Long workerId) {
        this.bookingId = bookingId;
        this.workerId = workerId;
    }

    public Long getId() { return id; }
    public Long getBookingId() { return bookingId; }
    public Long getWorkerId() { return workerId; }
    public Instant getCreatedAt() { return createdAt; }
}
