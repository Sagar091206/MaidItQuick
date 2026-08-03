package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
    List<Payment> findByBookingOrderByIdDesc(Booking booking);
    Optional<Payment> findByIdAndBooking(Long id, Booking booking);
    Optional<Payment> findTopByBookingOrderByIdDesc(Booking booking);
}
