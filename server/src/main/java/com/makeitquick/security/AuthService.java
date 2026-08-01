package com.makeitquick.security;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * Customer authentication and signup service.
 *
 * <p>Both the legacy {@code /api/auth/customer/**} routes and the canonical
 * {@code /api/customer/signup/**} routes delegate here so OTP issuance,
 * verification, retry limits and account creation stay in one place.</p>
 */
@Service
public class AuthService {
    private static final Duration CUSTOMER_SESSION = Duration.ofDays(30);

    private final UserRepository users;
    private final SessionRepository sessions;
    private final PartnerOtpRepository partnerOtps;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);
    private final SecureRandom random = new SecureRandom();

    AuthService(UserRepository users, SessionRepository sessions, PartnerOtpRepository partnerOtps) {
        this.users = users;
        this.sessions = sessions;
        this.partnerOtps = partnerOtps;
    }

    public Map<String, Object> startCustomerLogin(String rawPhone) {
        String phone = normalizeCustomerPhone(rawPhone);
        return otpChallenge(phone, null, PartnerOtpPurpose.CUSTOMER_LOGIN);
    }

    public Map<String, Object> verifyCustomerLogin(String rawPhone, String otp) {
        String phone = normalizeCustomerPhone(rawPhone);
        PartnerOtp challenge = latestValid(phone, PartnerOtpPurpose.CUSTOMER_LOGIN);
        challenge.attempt();
        if (!encoder.matches(otp, challenge.getOtpHash())) {
            partnerOtps.save(challenge);
            throwInvalidOtp(challenge);
        }
        UserAccount user = findOrCreateCustomer(phone);
        challenge.consume();
        partnerOtps.save(challenge);
        return sessionResponse(user);
    }

    public Map<String, Object> startCustomerSignup(String name, String rawPhone, String email) {
        String phone = normalizeCustomerPhone(rawPhone);
        users.findByPhoneAndRole(phone, Role.CUSTOMER).ifPresent(user -> {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "An account already exists for this phone number. Sign in instead.");
        });
        if (email != null && !email.isBlank()
                && users.findByEmailIgnoreCase(email.trim().toLowerCase()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered.");
        }
        return otpChallenge(phone, name.trim(), PartnerOtpPurpose.CUSTOMER_SIGNUP);
    }

    public Map<String, Object> verifyCustomerSignup(String name, String rawPhone, String email, String otp) {
        String phone = normalizeCustomerPhone(rawPhone);
        PartnerOtp challenge = latestValid(phone, PartnerOtpPurpose.CUSTOMER_SIGNUP);
        challenge.attempt();
        if (!encoder.matches(otp, challenge.getOtpHash())) {
            partnerOtps.save(challenge);
            throwInvalidOtp(challenge);
        }
        UserAccount user = createCustomer(phone, name, email);
        challenge.consume();
        partnerOtps.save(challenge);
        return sessionResponse(user);
    }

    private PartnerOtp latestValid(String phone, PartnerOtpPurpose purpose) {
        return partnerOtps
                .findTopByPhoneAndPurposeAndConsumedFalseOrderByIdDesc(phone, purpose)
                .filter(PartnerOtp::valid)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "OTP is invalid or expired. Request a new OTP."));
    }

    private void throwInvalidOtp(PartnerOtp challenge) {
        if (challenge.getAttempts() >= 5) {
            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED, "Maximum OTP attempts reached. Request a new OTP.");
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Incorrect OTP. Try again.");
    }

    private Map<String, Object> sessionResponse(UserAccount user) {
        String token = token();
        sessions.save(new Session(token, user, Instant.now().plus(CUSTOMER_SESSION)));
        return Map.of("token", token, "role", user.getRole(), "name", user.getName());
    }

    private Map<String, Object> otpChallenge(String phone, String name, PartnerOtpPurpose purpose) {
        String otp = String.format("%06d", random.nextInt(1_000_000));
        partnerOtps.save(new PartnerOtp(
                phone, name, purpose, encoder.encode(otp), Instant.now().plus(Duration.ofMinutes(10))));
        return Map.of("message", "OTP sent", "phone", phone, "expiresInSeconds", 600, "devOtp", otp);
    }

    private UserAccount findOrCreateCustomer(String phone) {
        return users.findByPhoneAndRole(phone, Role.CUSTOMER)
                .filter(UserAccount::isEnabled)
                .orElseGet(() -> {
                    UserAccount user = new UserAccount(
                            "",
                            "",
                            encoder.encode(token()),
                            phone,
                            Role.CUSTOMER);
                    user.setEmailNotifications(false);
                    return users.save(user);
                });
    }

    private UserAccount createCustomer(String phone, String name, String email) {
        users.findByPhoneAndRole(phone, Role.CUSTOMER).ifPresent(user -> {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "An account already exists for this phone number. Sign in instead.");
        });
        String cleanEmail = email == null || email.isBlank() ? "" : email.trim().toLowerCase();
        if (!cleanEmail.isBlank() && users.findByEmailIgnoreCase(cleanEmail).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered.");
        }
        UserAccount user = new UserAccount(name.trim(), cleanEmail, encoder.encode(token()), phone, Role.CUSTOMER);
        user.setEmailNotifications(false);
        user.setProfileCompleted(false);
        return users.save(user);
    }

    /**
     * Normalizes a customer phone to E.164.
     *
     * <p>Bare 10-digit numbers default to the Indian launch market ({@code +91}).
     * Numbers that already carry an international prefix are validated and kept
     * as-is so the app country picker can support more markets later.</p>
     */
    public String normalizeCustomerPhone(String raw) {
        String compact = raw.trim().replaceAll("[\\s\\-().]", "");
        if (compact.startsWith("00")) {
            compact = "+" + compact.substring(2);
        }
        if (compact.startsWith("+91")) {
            String national = compact.substring(3);
            if (!national.matches("\\d{10}")) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "Enter a valid 10-digit mobile number.");
            }
            return "+91" + national;
        }
        if (compact.startsWith("+")) {
            if (!compact.matches("\\+[1-9]\\d{7,14}")) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "Enter a valid phone number with country code.");
            }
            return compact;
        }
        if (compact.startsWith("91") && compact.length() == 12) {
            compact = compact.substring(2);
        } else if (compact.startsWith("0") && compact.length() == 11) {
            compact = compact.substring(1);
        }
        if (!compact.matches("\\d{10}")) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Enter a valid 10-digit mobile number.");
        }
        return "+91" + compact;
    }

    private String token() {
        byte[] bytes = new byte[48];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
