package com.makeitquick.security;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ResetTokenRepository extends JpaRepository<ResetToken, Long> {
    Optional<ResetToken> findByToken(String token);

    /** Invalidates every previous active reset token so only the newest one works. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update ResetToken t set t.used = true where t.user = :user and t.used = false")
    int markAllUsedFor(@Param("user") UserAccount user);
}
