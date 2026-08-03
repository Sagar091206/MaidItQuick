package com.maiditquick.admin.settlements;

import com.maiditquick.admin.partners.Partner;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.Optional;

public interface PayoutRecordRepository
    extends JpaRepository<PayoutRecord, Long>, JpaSpecificationExecutor<PayoutRecord> {

  Optional<PayoutRecord> findByPartnerAndPeriodLabel(Partner partner, String periodLabel);
}
