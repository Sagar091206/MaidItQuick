package com.makeitquick.admin.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Login request payload (US 1.1).
 *
 * @param email      admin email address
 * @param password   plain-text password, never logged or stored
 * @param rememberMe when true the refresh cookie is persisted for 7 days;
 *                   when false (default) it is a session-only cookie
 */
public record LoginRequest(
        @Email(message = "Enter a valid email address")
        @NotBlank(message = "Email is required")
        String email,

        @NotBlank(message = "Password is required")
        @Size(min = 8, max = 128, message = "Password must be between 8 and 128 characters")
        String password,

        Boolean rememberMe) {
}
