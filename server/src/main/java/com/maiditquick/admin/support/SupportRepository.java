package com.maiditquick.admin.support;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface SupportRepository extends JpaRepository<SupportRequest, Long>, JpaSpecificationExecutor<SupportRequest> {
  long countByStatus(String status);
}
