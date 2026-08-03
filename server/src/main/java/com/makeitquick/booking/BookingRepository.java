package com.makeitquick.booking;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface BookingRepository extends JpaRepository<Booking,Long>{
 List<Booking> findByCustomerIdOrderByIdDesc(Long id);
 List<Booking> findByWorkerIdOrderByIdDesc(Long id);
 List<Booking> findByWorkerIdAndStatusIn(Long workerId, Collection<BookingStatus> statuses);
 boolean existsByCustomerIdAndStatusIn(Long customerId, java.util.Collection<BookingStatus> statuses);
}
