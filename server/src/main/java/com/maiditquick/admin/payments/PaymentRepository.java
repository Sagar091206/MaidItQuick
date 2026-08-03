package com.maiditquick.admin.payments;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.math.BigDecimal;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
  Page<Payment> findByStatusContainingIgnoreCase(String status, Pageable pageable);

  long countByStatus(String status);

  @Query("SELECT COALESCE(SUM(p.amount), 0) FROM AdminPayment p WHERE p.status = 'PAID'")
  BigDecimal sumPaid();
}
