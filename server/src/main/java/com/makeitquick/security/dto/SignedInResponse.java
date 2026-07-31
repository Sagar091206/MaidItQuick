package com.makeitquick.security.dto;

/**
 * Response for {@code POST /api/v1/auth/verify-otp} when the phone already
 * belongs to a customer, and for {@code POST /api/v1/auth/complete-profile}.
 *
 * @param existing         always {@code true} for this shape
 * @param token            signed JWT for the signed-in customer
 * @param role             account role, always {@code CUSTOMER}
 * @param name             customer display name
 * @param phone            normalized E.164 phone number
 * @param profileComplete  whether the profile is ready for bookings
 */
public record SignedInResponse(
        boolean existing,
        String token,
        String role,
        String name,
        String phone,
        boolean profileComplete) implements AuthV1Response {
}
