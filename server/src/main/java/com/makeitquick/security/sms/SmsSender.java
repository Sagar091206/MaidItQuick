package com.makeitquick.security.sms;

/**
 * Abstraction over the SMS delivery provider.
 *
 * <p>Authentication code depends only on this interface. The application
 * configures exactly one implementation: a logging sender for local
 * development (SMS_ENABLED=false) or a real provider integration in
 * production. Providers are free to throw inside {@link #sendOtp}; callers
 * treat failures as a failed delivery attempt.</p>
 */
public interface SmsSender {

    /**
     * Delivers a one-time password to the given E.164 phone number.
     *
     * @param phone   normalized E.164 number, for example {@code +919876543210}
     * @param otp     the six-digit code
     * @param purpose human-readable reason, for example "customer-login"
     */
    void sendOtp(String phone, String otp, String purpose);
}
