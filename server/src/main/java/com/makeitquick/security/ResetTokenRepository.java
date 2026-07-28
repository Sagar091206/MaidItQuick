package com.makeitquick.security;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
interface ResetTokenRepository extends JpaRepository<ResetToken,Long>{Optional<ResetToken> findByToken(String token);}
