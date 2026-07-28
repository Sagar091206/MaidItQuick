package com.makeitquick.security;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface SessionRepository extends JpaRepository<Session,Long>{Optional<Session> findByToken(String token);}
