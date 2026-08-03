package com.maiditquick.admin.config;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

/**
 * Fails fast at startup when the two JWT signing secrets are misconfigured.
 * The mobile realm ({@code app.security.jwt-secret}) and the admin realm
 * ({@code app.jwt.secret}) must use distinct, sufficiently long secrets so a
 * token minted for one realm can never be accepted as valid in the other.
 */
@Configuration
public class JwtSecretGuard {

    private final String mobileSecret;
    private final String adminSecret;

    JwtSecretGuard(@Value("${app.security.jwt-secret}") String mobileSecret,
                   @Value("${app.jwt.secret}") String adminSecret) {
        this.mobileSecret = mobileSecret;
        this.adminSecret = adminSecret;
    }

    @PostConstruct
    void verify() {
        requireStrong(mobileSecret, "app.security.jwt-secret");
        requireStrong(adminSecret, "app.jwt.secret");
        if (mobileSecret.equals(adminSecret)) {
            throw new IllegalStateException(
                    "app.security.jwt-secret and app.jwt.secret must be distinct; sharing one "
                    + "secret between the mobile and admin realms allows cross-realm token confusion");
        }
    }

    private static void requireStrong(String secret, String key) {
        if (secret == null || secret.length() < 32) {
            throw new IllegalStateException(key + " must be at least 32 characters");
        }
    }
}
