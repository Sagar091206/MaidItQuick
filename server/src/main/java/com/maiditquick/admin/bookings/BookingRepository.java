package com.maiditquick.admin.bookings;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface BookingRepository extends JpaRepository<Booking, Long>, JpaSpecificationExecutor<Booking> {
  @Query("SELECT b FROM Booking b WHERE lower(cast(b.customer.name as string)) LIKE lower(concat('%', :q, '%')) "
      + "OR lower(cast(b.service.name as string)) LIKE lower(concat('%', :q, '%')) OR lower(b.status) LIKE lower(concat('%', :q, '%'))")
  Page<Booking> search(@Param("q") String q, Pageable pageable);

  long countByStatus(String status);

  long countByCreatedAtGreaterThanEqual(Instant since);

  long countByCustomerId(Long customerId);

  List<Booking> findByStatusIn(List<String> statuses);

  @Query("SELECT COUNT(b) FROM Booking b WHERE b.status = 'PENDING'")
  long countPending();
}
