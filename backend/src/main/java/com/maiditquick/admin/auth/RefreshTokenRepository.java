package com.maiditquick.admin.auth;

import com.maiditquick.admin.admin.Admin;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHashAndRevokedAtIsNull(String hash);

    List<RefreshToken> findByAdminIdAndRevokedAtIsNullOrderByIdDesc(Long adminId);

    Optional<RefreshToken> findByIdAndAdminIdAndRevokedAtIsNull(Long id, Long adminId);

    /** Revoke every live refresh session of an admin (used on password reset). */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update RefreshToken t set t.revokedAt = :now where t.admin = :admin and t.revokedAt is null")
    int revokeAllFor(@Param("admin") Admin admin, @Param("now") Instant now);

    /** Revoke every live session except the one presenting the change. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update RefreshToken t set t.revokedAt = :now where t.admin = :admin and t.revokedAt is null and t.tokenHash <> :keepHash")
    int revokeAllExcept(@Param("admin") Admin admin, @Param("keepHash") String keepHash, @Param("now") Instant now);
}
