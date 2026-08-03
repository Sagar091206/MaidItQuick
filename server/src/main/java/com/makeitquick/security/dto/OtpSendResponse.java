package com.makeitquick.security.dto;

/**
 * Response for {@code POST /api/v1/auth/send-otp}.
 *
 * <p>{@code devOtp} is populated only while SMS delivery is disabled
 * (SMS_ENABLED=false) so local development can complete the flow.</p>
 *
 * @param message          success message
 * @param phone            normalized E.164 phone number
 * @param expiresInSeconds OTP lifetime in seconds
 * @param devOtp           development-only plaintext OTP, or {@code null}
 */
public record OtpSendResponse(String message, String phone, int expiresInSeconds, String devOtp)
        implements AuthV1Response {
}
