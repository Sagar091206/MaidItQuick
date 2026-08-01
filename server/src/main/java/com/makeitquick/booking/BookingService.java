package com.makeitquick.booking;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "booking_services")
public class BookingService {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false) private Booking booking;
    @Column(nullable = false) private String serviceName;

    protected BookingService() {}

    BookingService(Booking booking, String serviceName) {
        this.booking = booking;
        this.serviceName = serviceName;
    }

    public Long getId() { return id; }
    public Booking getBooking() { return booking; }
    public String getServiceName() { return serviceName; }
}
