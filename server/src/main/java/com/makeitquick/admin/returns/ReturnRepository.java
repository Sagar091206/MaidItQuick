package com.makeitquick.admin.returns;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface ReturnRepository extends JpaRepository<ReturnRequest, Long>, JpaSpecificationExecutor<ReturnRequest> {
  long countByStatus(String status);
  java.util.Optional<ReturnRequest> findTopByBookingIdOrderByCreatedAtDesc(Long bookingId);
}
