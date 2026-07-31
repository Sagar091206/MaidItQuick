package com.makeitquick.security;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PartnerOtpRepository extends JpaRepository<PartnerOtp, Long> {
    Optional<PartnerOtp> findTopByPhoneAndPurposeAndConsumedFalseOrderByIdDesc(String phone, PartnerOtpPurpose purpose);

    long countByPhoneAndPurposeAndCreatedAtAfter(String phone, PartnerOtpPurpose purpose, Instant after);
}
