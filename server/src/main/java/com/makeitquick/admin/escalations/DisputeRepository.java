package com.makeitquick.admin.escalations;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface DisputeRepository
    extends JpaRepository<Dispute, Long>, JpaSpecificationExecutor<Dispute> {

  long countByStatus(String status);
}
