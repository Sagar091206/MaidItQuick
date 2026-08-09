package com.makeitquick.security;

import io.jsonwebtoken.Claims;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * Resolves the current user from an {@code Authorization} header.
 *
 * <p>Both the security filter and the business controllers call into this
 * single place so every protected endpoint accepts the new signed JWT issued
 * by {@code /api/v1/auth} as well as the legacy opaque session tokens.</p>
 */
@Component
public class SessionResolver {

    private final JwtService jwt;
    private final UserRepository users;
    private final SessionRepository sessions;

    SessionResolver(JwtService jwt, UserRepository users, SessionRepository sessions) {
        this.jwt = jwt;
        this.users = users;
        this.sessions = sessions;
    }

    /** Returns the user behind the bearer header, if the token is valid. */
    public Optional<UserAccount> fromBearer(String authorization) {
        String token = bearerToken(authorization);
        if (token.isEmpty()) return Optional.empty();
        Claims claims = jwt.parse(token);
        if (claims != null) {
            try {
                return users.findById(Long.parseLong(claims.getSubject())).filter(UserAccount::isEnabled);
            } catch (NumberFormatException e) {
                return Optional.empty();
            }
        }
        return sessions.findByToken(token)
                .filter(Session::valid)
                .map(Session::getUser);
    }

    /** Extracts the raw token, or an empty string when the header is absent or not a bearer token. */
    public static String bearerToken(String authorization) {
        if (authorization == null) return "";
        return authorization.replaceFirst("(?i)^Bearer\\s+", "").trim();
    }
}
