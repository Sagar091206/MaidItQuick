package com.makeitquick.admin.reviews;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ReviewRepository extends JpaRepository<Review, Long> {
  Page<Review> findByStatusIgnoreCase(String status, Pageable pageable);
  long countByStatus(String status);

  @Query("SELECT COALESCE(AVG(r.rating), 0) FROM Review r WHERE r.status = 'APPROVED'")
  Double averageApprovedRating();
}
