package com.makeitquick.admin.auth;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

/**
 * Domain exceptions for the authentication flow (US 1.1 / 1.2).
 * Each maps to a specific HTTP status in AdminApiExceptionHandler:
 *  - InvalidCredentialsException  -> 401
 *  - AccountDisabledException     -> 403
 *  - LoginLockedException         -> 429 + Retry-After
 *  - PasswordResetMailException   -> 500 (generic message)
 */
public final class AuthExceptions {

    private AuthExceptions() {
    }

    /** Wrong email/password (or unknown account — never reveal which). */
    public static class InvalidCredentialsException extends RuntimeException {
        public InvalidCredentialsException(String message) {
            super(message);
        }
    }

    /** Account exists but is disabled. */
    public static class AccountDisabledException extends RuntimeException {
        public AccountDisabledException(String message) {
            super(message);
        }
    }

    /** Account temporarily locked after repeated failed attempts. */
    public static class LoginLockedException extends RuntimeException {
        private final long retryAfterSeconds;

        private LoginLockedException(String message, long retryAfterSeconds) {
            super(message);
            this.retryAfterSeconds = retryAfterSeconds;
        }

        /** Build a 429 lockout for an account locked until {@code lockedUntil}. */
        public static LoginLockedException until(Instant lockedUntil) {
            long seconds = Math.max(1, Instant.now().until(lockedUntil, ChronoUnit.SECONDS));
            long minutes = Math.max(1, (seconds + 59) / 60);
            return new LoginLockedException(
                    "Too many login attempts. Try again in " + minutes + " minute" + (minutes == 1 ? "" : "s") + ".",
                    seconds);
        }

        /** Seconds until the lock expires (for the Retry-After header). */
        public long retryAfterSeconds() {
            return retryAfterSeconds;
        }
    }

    /** Reset email could not be delivered (SMTP failure) -> generic 500. */
    public static class PasswordResetMailException extends RuntimeException {
        public PasswordResetMailException() {
            super("Unable to process your request. Please try again later.");
        }
    }

    /** Reset token missing, unknown, already used or expired -> 400. */
    public static class InvalidResetTokenException extends RuntimeException {
        public InvalidResetTokenException() {
            super("This password reset link is invalid or has expired.");
        }
    }
}
