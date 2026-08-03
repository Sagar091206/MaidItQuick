package com.makeitquick.admin.auth;

import com.makeitquick.security.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHashAndRevokedAtIsNull(String hash);

    List<RefreshToken> findByUserIdAndRevokedAtIsNullOrderByIdDesc(Long userId);

    Optional<RefreshToken> findByIdAndUserIdAndRevokedAtIsNull(Long id, Long userId);

    /** Revoke every live refresh session of a user (used on password reset). */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update RefreshToken t set t.revokedAt = :now where t.user = :user and t.revokedAt is null")
    int revokeAllFor(@Param("user") UserAccount user, @Param("now") Instant now);

    /** Revoke every live session except the one presenting the change. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update RefreshToken t set t.revokedAt = :now where t.user = :user and t.revokedAt is null and t.tokenHash <> :keepHash")
    int revokeAllExcept(@Param("user") UserAccount user, @Param("keepHash") String keepHash, @Param("now") Instant now);
}
