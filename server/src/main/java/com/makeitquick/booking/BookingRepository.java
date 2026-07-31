package com.makeitquick.booking;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface BookingRepository extends JpaRepository<Booking,Long>{List<Booking> findByCustomerIdOrderByIdDesc(Long id);List<Booking> findByWorkerIdOrderByIdDesc(Long id);}
