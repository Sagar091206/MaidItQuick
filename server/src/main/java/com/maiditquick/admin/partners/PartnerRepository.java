package com.maiditquick.admin.partners;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PartnerRepository extends JpaRepository<Partner, Long>, JpaSpecificationExecutor<Partner> {
  boolean existsByPhone(String phone);
  boolean existsByPhoneAndIdNot(String phone, Long id);
  long countByKycStatus(String status);
  long countByKycStatusAndDeletedAtIsNull(String status);
  Page<Partner> findByKycStatus(String status, Pageable pageable);

  @Query("SELECT p FROM Partner p "
      + "WHERE (:status IS NULL OR p.kycStatus = :status) "
      + "AND (lower(p.name) LIKE lower(concat('%', :q, '%')) "
      + "OR lower(p.phone) LIKE lower(concat('%', :q, '%')) "
      + "OR lower(p.email) LIKE lower(concat('%', :q, '%')))")
  Page<Partner> search(@Param("status") String status, @Param("q") String q, Pageable pageable);
}
