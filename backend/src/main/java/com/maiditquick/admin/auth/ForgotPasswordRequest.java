package com.maiditquick.admin.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Forgot-password request payload (US 1.2).
 * The email is normalized (trimmed, lowercased) inside the service;
 * validation here only rejects empty/malformed/oversized values.
 */
public record ForgotPasswordRequest(

        @NotBlank(message = "Email is required")
        @Email(message = "Enter a valid email address")
        @Size(max = 254, message = "Email must be 254 characters or fewer")
        String email) {
}
