package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
    List<Payment> findByBookingOrderByIdDesc(Booking booking);
    Optional<Payment> findByIdAndBooking(Long id, Booking booking);
    Optional<Payment> findTopByBookingOrderByIdDesc(Booking booking);

    Page<Payment> findByStatus(PaymentStatus status, Pageable pageable);

    long countByStatus(PaymentStatus status);

    @Query("SELECT COALESCE(SUM(p.amountPaise), 0) FROM Payment p WHERE p.status = :status")
    long sumAmountPaiseByStatus(PaymentStatus status);
}
