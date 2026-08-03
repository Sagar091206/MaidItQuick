package com.makeitquick.security;

import com.makeitquick.common.ProfilePhotos;
import com.makeitquick.security.dto.AuthV1Response;
import com.makeitquick.security.dto.OtpSendResponse;
import com.makeitquick.security.dto.PendingRegistrationResponse;
import com.makeitquick.security.dto.SignedInResponse;
import com.makeitquick.security.sms.SmsSender;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Unified customer authentication flow.
 *
 * <p>Implements the single path used by the mobile app: send OTP, verify OTP,
 * and either sign the existing customer in or issue a short-lived pending
 * registration token that {@link #completeProfile} exchanges for an account.
 * OTPs expire after a short window (default 300 seconds), resends are rate
 * limited and capped, failed attempts lock the challenge after five tries, and
 * delivery goes through the configured {@link SmsSender}.</p>
 */
@Service
public class AuthV1Service {
    private static final Logger log = LoggerFactory.getLogger(AuthV1Service.class);

    private static final Duration PENDING_EXPIRY = Duration.ofMinutes(30);

    private final UserRepository users;
    private final PartnerOtpRepository partnerOtps;
    private final PendingRegistrationRepository pendingRegistrations;
    private final OtpRateLimiter rateLimiter;
    private final AuthService auth;
    private final JwtService jwt;
    private final SmsSender sms;
    private final Duration otpExpiry;
    private final int maxAttempts;
    private final int maxSends;
    private final Duration sendWindow;
    private final boolean devOtpEcho;
    private final PasswordEncoder encoder;
    private final SecureRandom random = new SecureRandom();

    AuthV1Service(UserRepository users, PartnerOtpRepository partnerOtps,
                  PendingRegistrationRepository pendingRegistrations, OtpRateLimiter rateLimiter,
                  AuthService auth, JwtService jwt, SmsSender sms, PasswordEncoder encoder,
                  @Value("${app.security.otp.expiry-seconds:60}") long otpExpirySeconds,
                  @Value("${app.security.otp.max-attempts:5}") int maxAttempts,
                  @Value("${app.security.otp.max-sends:4}") int maxSends,
                  @Value("${app.security.otp.send-window-minutes:10}") long sendWindowMinutes,
                  @Value("${app.sms.enabled:false}") boolean smsEnabled) {
        this.users = users;
        this.partnerOtps = partnerOtps;
        this.pendingRegistrations = pendingRegistrations;
        this.rateLimiter = rateLimiter;
        this.auth = auth;
        this.jwt = jwt;
        this.sms = sms;
        this.otpExpiry = Duration.ofSeconds(otpExpirySeconds);
        this.maxAttempts = maxAttempts;
        this.maxSends = maxSends;
        this.sendWindow = Duration.ofMinutes(sendWindowMinutes);
        this.devOtpEcho = !smsEnabled;
        this.encoder = encoder;
    }

    /**
     * Issues a six-digit OTP for the given phone. A phone may receive at most
     * {@code maxSends} OTPs (the initial send plus resends) inside a sliding
     * window; further requests are rejected with {@code 429}.
     */
    @Transactional
    public AuthV1Response sendOtp(String rawPhone) {
        String phone = auth.normalizeCustomerPhone(rawPhone);
        if (!rateLimiter.allow("otp-send:" + phone, maxSends, sendWindow)) {
            throw new ResponseStatusException(
                    HttpStatus.TOO_MANY_REQUESTS,
                    "Too many OTP requests for this number. Try again in a few minutes.");
        }
        String otp = String.format("%06d", random.nextInt(1_000_000));
        partnerOtps.save(new PartnerOtp(
                phone, null, PartnerOtpPurpose.CUSTOMER_AUTH,
                encoder.encode(otp), Instant.now().plus(otpExpiry)));
        sms.sendOtp(phone, otp, "customer-login");
        log.info("OTP issued for {} (customer auth)", mask(phone));
        return new OtpSendResponse("OTP sent", phone, (int) otpExpiry.toSeconds(),
                devOtpEcho ? otp : null);
    }

    /**
     * Verifies an OTP. On success an existing customer receives a signed JWT;
     * a new customer receives a pending registration token that the profile
     * completion step must exchange. Failed attempts are counted and the
     * challenge locks after {@code maxAttempts} failures.
     *
     * <p>Not annotated with {@code @Transactional} on purpose: failed attempts
     * are persisted through the repository's own transaction before the error
     * response is thrown, so the counter survives the exception. Wrapping this
     * method in one transaction would roll the attempt back with it.</p>
     */
    public AuthV1Response verifyOtp(String rawPhone, String otp) {
        String phone = auth.normalizeCustomerPhone(rawPhone);
        PartnerOtp challenge = latestValid(phone);
        boolean matched = otp != null && encoder.matches(otp, challenge.getOtpHash());
        if (!matched) {
            challenge.attempt();
            partnerOtps.save(challenge);
            throwInvalidOtp(challenge);
        }
        challenge.consume();
        partnerOtps.save(challenge);

        var existing = users.findByPhoneAndRole(phone, Role.CUSTOMER).filter(UserAccount::isEnabled);
        if (existing.isPresent()) {
            UserAccount user = existing.get();
            log.info("OTP verified for {} (existing customer)", mask(phone));
            return signedIn(user);
        }
        String pendingToken = token();
        pendingRegistrations.save(new PendingRegistration(
                phone, pendingToken, Instant.now().plus(PENDING_EXPIRY)));
        log.info("OTP verified for {} (new customer, pending registration)", mask(phone));
        return new PendingRegistrationResponse(false, pendingToken, phone);
    }

    /**
     * Creates the customer account for a phone that passed OTP verification,
     * marks the profile as complete and signs the customer in.
     */
    @Transactional
    public AuthV1Response completeProfile(String pendingToken, String name, String email,
                                          String gender, LocalDate dob, String profileImage) {
        if (pendingToken == null || pendingToken.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Verification is missing. Request a new OTP.");
        }
        PendingRegistration pending = pendingRegistrations.findByToken(pendingToken)
                .filter(PendingRegistration::valid)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Verification expired or already used. Request a new OTP."));
        String phone = pending.getPhone();
        users.findByPhoneAndRole(phone, Role.CUSTOMER).ifPresent(user -> {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "An account already exists for this phone number. Sign in instead.");
        });
        String cleanName = name == null ? "" : name.trim();
        if (cleanName.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter your full name.");
        }
        String cleanEmail = email == null || email.isBlank() ? "" : email.trim().toLowerCase();
        if (!cleanEmail.isBlank() && users.findByEmailIgnoreCase(cleanEmail).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered.");
        }
        String photo = normalizePhoto(profileImage);
        UserAccount user = new UserAccount(cleanName, cleanEmail, encoder.encode(token()), phone, Role.CUSTOMER);
        user.setEmailNotifications(false);
        user.setProfileCompleted(true);
        if (gender != null && !gender.isBlank()) user.setGender(gender);
        if (dob != null) user.setDob(dob);
        if (photo != null) user.setProfileImage(photo);
        users.save(user);
        pending.consume();
        pendingRegistrations.save(pending);
        log.info("Customer account created for {}", mask(phone));
        return signedIn(user);
    }

    private SignedInResponse signedIn(UserAccount user) {
        String token = jwt.issue(user);
        return new SignedInResponse(
                true, token, user.getRole().name(),
                user.getName(), user.getPhone(), user.profileComplete());
    }

    private PartnerOtp latestValid(String phone) {
        return partnerOtps
                .findTopByPhoneAndPurposeAndConsumedFalseOrderByIdDesc(phone, PartnerOtpPurpose.CUSTOMER_AUTH)
                .filter(PartnerOtp::valid)
                .filter(challenge -> challenge.getAttempts() < maxAttempts)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "OTP is invalid or expired. Request a new OTP."));
    }

    private void throwInvalidOtp(PartnerOtp challenge) {
        if (challenge.getAttempts() >= maxAttempts) {
            log.warn("OTP locked for {} after repeated failures", mask(challenge.getPhone()));
            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED, "Maximum OTP attempts reached. Request a new OTP.");
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Incorrect OTP. Try again.");
    }

    private static String normalizePhoto(String profileImage) {
        try {
            return ProfilePhotos.normalize(profileImage);
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, e.getMessage());
        }
    }

    private String token() {
        byte[] bytes = new byte[48];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static String mask(String phone) {
        if (phone == null || phone.length() < 6) return "unknown";
        return phone.substring(0, phone.length() - 4) + "****";
    }
}
