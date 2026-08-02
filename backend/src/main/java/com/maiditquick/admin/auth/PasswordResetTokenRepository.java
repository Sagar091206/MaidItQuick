package com.maiditquick.admin.auth;

import com.maiditquick.admin.admin.Admin;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {

    Optional<PasswordResetToken> findByTokenHash(String tokenHash);

    Optional<PasswordResetToken> findByTokenHashAndUsedFalseAndExpiresAtAfter(
            String tokenHash, Instant now);

    /** Invalidate every still-active token of an admin (US 1.2: only the newest stays valid). */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update PasswordResetToken t set t.used = true where t.admin = :admin and t.used = false")
    int markAllUsedFor(@Param("admin") Admin admin);
}
