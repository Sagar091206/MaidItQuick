package com.makeitquick.security;

import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;

interface PartnerOtpRepository extends JpaRepository<PartnerOtp,Long> {
 Optional<PartnerOtp> findTopByPhoneAndPurposeAndConsumedFalseOrderByIdDesc(String phone,PartnerOtpPurpose purpose);
}
