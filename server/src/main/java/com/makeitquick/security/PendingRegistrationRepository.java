package com.makeitquick.security;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PendingRegistrationRepository extends JpaRepository<PendingRegistration, Long> {
    Optional<PendingRegistration> findByToken(String token);

    Optional<PendingRegistration> findTopByPhoneAndUsedFalseOrderByIdDesc(String phone);
}
