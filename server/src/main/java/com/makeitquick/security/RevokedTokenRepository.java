package com.makeitquick.security;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RevokedTokenRepository extends JpaRepository<RevokedToken, Long> {

    Optional<RevokedToken> findByTokenHash(String tokenHash);

    void deleteByExpiresAtBefore(Instant cutoff);
}
