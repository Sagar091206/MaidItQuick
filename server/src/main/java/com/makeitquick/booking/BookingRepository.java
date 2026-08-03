package com.makeitquick.booking;
import com.makeitquick.payment.PaymentStatus;
import java.time.Instant;
import java.util.*; import org.springframework.data.domain.Page; import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
public interface BookingRepository extends JpaRepository<Booking,Long>, JpaSpecificationExecutor<Booking>{
 List<Booking> findByCustomerIdOrderByIdDesc(Long id);
 List<Booking> findByWorkerIdOrderByIdDesc(Long id);
 List<Booking> findByWorkerIdAndStatusIn(Long workerId, Collection<BookingStatus> statuses);
 List<Booking> findByStatusOrderByIdDesc(BookingStatus status);
 List<Booking> findByStatusIn(Collection<BookingStatus> statuses);
 boolean existsByCustomerIdAndStatusIn(Long customerId, java.util.Collection<BookingStatus> statuses);

 long countByStatus(BookingStatus status);
 long countByPaymentStatus(PaymentStatus paymentStatus);
 long countByCustomerId(Long customerId);
 long countByCreatedAtGreaterThanEqual(Instant since);

 @Query("SELECT b FROM Booking b WHERE lower(b.customer.name) LIKE lower(concat('%', :q, '%')) "
   + "OR lower(b.service) LIKE lower(concat('%', :q, '%')) "
   + "OR lower(b.customer.phone) LIKE lower(concat('%', :q, '%'))")
 Page<Booking> search(String q, Pageable pageable);
}
