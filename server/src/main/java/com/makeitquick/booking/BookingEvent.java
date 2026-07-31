package com.makeitquick.booking;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "booking_events")
public class BookingEvent {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    private Booking booking;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BookingStatus status;

    @Column(length = 500)
    private String note;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected BookingEvent() {}

    BookingEvent(Booking booking, BookingStatus status, String note) {
        this.booking = booking;
        this.status = status;
        this.note = note == null ? "" : note;
    }

    public Long getId() { return id; }
    public Booking getBooking() { return booking; }
    public BookingStatus getStatus() { return status; }
    public String getNote() { return note == null ? "" : note; }
    public Instant getCreatedAt() { return createdAt; }
}
