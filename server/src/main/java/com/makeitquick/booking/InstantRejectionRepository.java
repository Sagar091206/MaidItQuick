package com.makeitquick.booking;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

interface InstantRejectionRepository extends JpaRepository<InstantRejection, Long> {
    boolean existsByBookingIdAndWorkerId(Long bookingId, Long workerId);
    List<InstantRejection> findByWorkerId(Long workerId);
}