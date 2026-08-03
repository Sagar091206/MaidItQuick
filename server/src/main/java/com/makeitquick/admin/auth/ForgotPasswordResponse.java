package com.makeitquick.admin.auth;

/**
 * Forgot-password response (US 1.2).
 * Always the same generic message — whether or not the account exists,
 * so the endpoint never leaks registered email addresses.
 */
public record ForgotPasswordResponse(String message) {

    public static ForgotPasswordResponse generic() {
        return new ForgotPasswordResponse("If an account exists, a password reset link has been sent.");
    }
}
