package com.makeitquick.booking;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BookingServiceRepository extends JpaRepository<BookingService, Long> {
    List<BookingService> findByBookingIdOrderByIdAsc(Long bookingId);
}
