package com.makeitquick.operations;
import org.springframework.data.jpa.repository.JpaRepository;
interface RefundRequestRepository extends JpaRepository<RefundRequest,Long> { boolean existsByBookingReference(String bookingReference); }
