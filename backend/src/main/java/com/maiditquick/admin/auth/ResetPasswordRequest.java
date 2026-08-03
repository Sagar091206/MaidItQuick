package com.maiditquick.admin.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Reset-password request (US 1.3): the raw token from the emailed link plus
 * the new password. The token is exactly 64 chars (Base64url, 48 random
 * bytes) and is never stored — only its SHA-256 digest is persisted.
 */
public record ResetPasswordRequest(
        @NotBlank(message = "Reset token is required")
        @Size(min = 64, max = 64, message = "Reset token is invalid")
        String token,

        @NotBlank(message = "New password is required")
        @Size(min = 8, max = 128, message = "New password must be 8 to 128 characters")
        String newPassword) {
}
