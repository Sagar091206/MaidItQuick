package com.makeitquick.security.dto;

/**
 * Response for {@code POST /api/v1/auth/verify-otp} when the phone has no
 * account yet. The client must collect profile details and exchange the
 * single-use {@code pendingToken} via {@code /api/v1/auth/complete-profile}.
 *
 * @param existing     always {@code false} for this shape
 * @param pendingToken single-use registration token, valid for 30 minutes
 * @param phone        normalized E.164 phone number
 */
public record PendingRegistrationResponse(boolean existing, String pendingToken, String phone)
        implements AuthV1Response {
}
