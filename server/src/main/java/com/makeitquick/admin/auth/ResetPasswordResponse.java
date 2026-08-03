package com.makeitquick.admin.auth;

/**
 * Reset-password response (US 1.3).
 */
public record ResetPasswordResponse(String message) {

    public static ResetPasswordResponse ok() {
        return new ResetPasswordResponse("Password changed successfully. You can now sign in with your new password.");
    }
}
