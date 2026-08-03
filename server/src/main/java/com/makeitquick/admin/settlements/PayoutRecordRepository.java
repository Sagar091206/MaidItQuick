package com.makeitquick.admin.settlements;

import com.makeitquick.security.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.Optional;

public interface PayoutRecordRepository
    extends JpaRepository<PayoutRecord, Long>, JpaSpecificationExecutor<PayoutRecord> {

  Optional<PayoutRecord> findByWorkerAndPeriodLabel(UserAccount worker, String periodLabel);
}
