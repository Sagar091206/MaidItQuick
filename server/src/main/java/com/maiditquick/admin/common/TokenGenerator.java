package com.maiditquick.admin.common;

import java.security.SecureRandom;
import java.util.Base64;

import org.springframework.stereotype.Component;

/**
 * Cryptographically secure token generator (US 1.2).
 * Produces a 64-character URL-safe token from 48 random bytes
 * (384-bit entropy, exceeding the 256-bit minimum requirement).
 */
@Component
public class TokenGenerator {

    private static final int RANDOM_BYTES = 48;

    private final SecureRandom random = new SecureRandom();

    public String generate() {
        byte[] bytes = new byte[RANDOM_BYTES];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
