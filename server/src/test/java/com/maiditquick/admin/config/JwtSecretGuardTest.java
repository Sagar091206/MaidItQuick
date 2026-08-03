package com.maiditquick.admin.config;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JwtSecretGuardTest {

    private static final String MOBILE = "makeitquick-local-dev-secret-change-me-0123456789abcdef";
    private static final String ADMIN = "mySuperSecretKeyThatIsAtLeast32CharactersLong123";

    @Test
    void acceptsDistinctStrongSecrets() {
        JwtSecretGuard guard = new JwtSecretGuard(MOBILE, ADMIN);
        assertDoesNotThrow(guard::verify);
    }

    @Test
    void rejectsIdenticalSecrets() {
        JwtSecretGuard guard = new JwtSecretGuard(MOBILE, MOBILE);
        assertThrows(IllegalStateException.class, guard::verify);
    }

    @Test
    void rejectsTooShortSecrets() {
        assertThrows(IllegalStateException.class, () -> new JwtSecretGuard("short", ADMIN).verify());
        assertThrows(IllegalStateException.class, () -> new JwtSecretGuard(MOBILE, "short").verify());
    }
}
