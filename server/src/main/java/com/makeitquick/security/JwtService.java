package com.makeitquick.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.HexFormat;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Issues and validates the signed JWTs returned by the unified customer auth
 * flow ({@code /api/v1/auth}). Tokens carry a unique id ({@code jti}), the
 * user id, phone, name and role, and expire after the configured number of
 * days.
 *
 * <p>JWT parsing never throws for callers: {@link #parse} returns {@code null}
 * for missing, expired, tampered or revoked tokens so the rest of the app can
 * fall back to the legacy opaque session lookup.</p>
 */
@Service
public class JwtService {

    private final SecretKey key;
    private final Duration expiry;
    private final RevokedTokenRepository revokedTokens;

    JwtService(@Value("${app.security.jwt-secret}") String secret,
               @Value("${app.security.jwt-expiry-days}") long expiryDays,
               RevokedTokenRepository revokedTokens) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expiry = Duration.ofDays(expiryDays);
        this.revokedTokens = revokedTokens;
    }

    public String issue(UserAccount user) {
        return issue(user, expiry);
    }

    /**
     * Issues a token with a caller-chosen lifetime (used by the admin realm for
     * short-lived access tokens). Admin tokens carry the full permission
     * catalog so {@code @PreAuthorize} checks work against the same issuer.
     */
    public String issue(UserAccount user, Duration ttl) {
        Instant now = Instant.now();
        var builder = Jwts.builder()
                .id(UUID.randomUUID().toString())
                .subject(String.valueOf(user.getId()))
                .claim("phone", user.getPhone())
                .claim("name", user.getName())
                .claim("role", user.getRole().name());
        if (user.getRole() == Role.ADMIN) {
            builder.claim("permissions", AdminPermissions.ALL);
        }
        return builder
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(ttl)))
                .signWith(key)
                .compact();
    }

    /** Returns the token claims, or {@code null} when the token is invalid, expired or revoked. */
    public Claims parse(String token) {
        if (token == null || token.isBlank()) return null;
        try {
            Claims claims = Jwts.parser().verifyWith(key).build()
                    .parseSignedClaims(token)
                    .getPayload();
            if (claims.getId() != null && revokedTokens.findByTokenHash(sha256(token)).isPresent()) {
                return null;
            }
            return claims;
        } catch (io.jsonwebtoken.JwtException | IllegalArgumentException e) {
            return null;
        }
    }

    /** Records the token as revoked so {@link #parse} stops accepting it. */
    public void revoke(String token) {
        if (token == null || token.isBlank()) return;
        Claims claims = parse(token);
        Instant cutoff = claims == null ? Instant.now().plus(expiry) : claims.getExpiration().toInstant();
        revokedTokens.save(new RevokedToken(sha256(token), cutoff));
    }

    @Scheduled(fixedRate = 3_600_000)
    @Transactional
    public void purgeRevoked() {
        revokedTokens.deleteByExpiresAtBefore(Instant.now());
    }

    static String sha256(String value) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
