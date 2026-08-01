package com.maiditquick.admin.security;

import com.maiditquick.admin.admin.Admin;
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.*;

@Service
public class JwtService {
  private final SecretKey key; private final long accessMinutes;
  public JwtService(@Value("${app.jwt.secret}") String secret, @Value("${app.jwt.access-minutes}") long accessMinutes) { this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8)); this.accessMinutes = accessMinutes; }
  public String create(Admin admin) { return Jwts.builder().subject(admin.getId().toString()).claim("email",admin.getEmail()).claim("role",admin.getRole().getCode()).claim("permissions",admin.getRole().getPermissions().stream().map(p->p.getCode()).toList()).issuedAt(new Date()).expiration(Date.from(Instant.now().plus(Duration.ofMinutes(accessMinutes)))).signWith(key).compact(); }
  public Claims claims(String token) { return Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload(); }
  public long expiresInSeconds() { return accessMinutes * 60; }
}
