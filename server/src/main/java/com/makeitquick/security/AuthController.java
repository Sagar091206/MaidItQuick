package com.makeitquick.security;

import com.makeitquick.common.ProfilePhotos;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.SecureRandom;
import java.time.*;
import java.util.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {
    private static final Logger log = LoggerFactory.getLogger(AuthController.class);
    private static final Duration DEFAULT_SESSION = Duration.ofHours(24);

    private final AuthService auth;
    private final UserRepository users;
    private final SessionRepository sessions;
    private final ResetTokenRepository resets;
    private final PartnerOtpRepository partnerOtps;
    private final SessionResolver resolver;
    private final JwtService jwt;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);
    private final SecureRandom random = new SecureRandom();

    @Value("${app.sms.enabled:false}")
    private boolean smsEnabled;

    private final ObjectProvider<JavaMailSender> mailSender;
    @Value("${app.mail.enabled:false}")
    private boolean mailEnabled;
    @Value("${app.mail.from:no-reply@maiditquick.local}")
    private String mailFrom;

    AuthController(
            AuthService auth,
            UserRepository u,
            SessionRepository s,
            ResetTokenRepository r,
            PartnerOtpRepository o,
            SessionResolver resolver,
            JwtService jwt,
            ObjectProvider<JavaMailSender> mailSender) {
        this.auth = auth;
        users = u;
        sessions = s;
        resets = r;
        partnerOtps = o;
        this.resolver = resolver;
        this.jwt = jwt;
        this.mailSender = mailSender;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, String> register(@Valid @RequestBody Register x) {
        String email = x.email().trim().toLowerCase();
        if (users.findByEmailIgnoreCase(email).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
        }
        Role role = Role.valueOf(x.role().toUpperCase());
        if (role == Role.ADMIN) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin accounts are created by the operator");
        }
        if (role == Role.WORKER) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Partner accounts are created through phone OTP onboarding. Use the partner sign-up flow instead.");
        }
        users.save(new UserAccount(x.name(), email, encoder.encode(x.password()), role));
        return Map.of("message", "Account created");
    }

    @PostMapping("/login")
    public Map<String, Object> login(@Valid @RequestBody Login x) {
        UserAccount u = users.findByEmailIgnoreCase(x.email())
                .filter(a -> encoder.matches(x.password(), a.getPasswordHash()) && a.isEnabled())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials"));
        return sessionResponse(u, DEFAULT_SESSION);
    }

    @PostMapping("/customer/otp/start")
    public Map<String, Object> startCustomerOtp(@Valid @RequestBody CustomerOtpStart x) {
        return auth.startCustomerLogin(x.phone());
    }

    @PostMapping("/customer/otp/verify")
    public Map<String, Object> verifyCustomerOtp(@Valid @RequestBody CustomerOtpVerify x) {
        return auth.verifyCustomerLogin(x.phone(), x.otp());
    }

    @PostMapping("/customer/signup/start")
    public Map<String, Object> startCustomerSignup(@Valid @RequestBody CustomerSignupStart x) {
        return auth.startCustomerSignup(x.name(), x.phone(), x.email());
    }

    @PostMapping("/customer/signup/verify")
    public Map<String, Object> verifyCustomerSignup(@Valid @RequestBody CustomerSignupVerify x) {
        return auth.verifyCustomerSignup(x.name(), x.phone(), x.email(), x.otp());
    }

    @GetMapping("/session")
    public Map<String, Object> currentSession(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        UserAccount user = resolver.fromBearer(authorization)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        return Map.of(
                "token", bearerToken(authorization),
                "role", user.getRole(),
                "name", user.getName(),
                "phone", user.getPhone());
    }

    @PostMapping("/logout")
    @Transactional
    public Map<String, String> logout(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        String token = bearerToken(authorization);
        if (!token.isBlank()) {
            if (jwt.parse(token) != null) {
                jwt.revoke(token);
            } else {
                sessions.deleteByToken(token);
            }
        }
        return Map.of("message", "Signed out");
    }

    @PostMapping("/partner/otp/signup/start")
    public Map<String, Object> startPartnerSignup(@Valid @RequestBody PartnerSignupStart x) {
        String phone = normalizePhone(x.phone());
        if (users.findByPhoneAndRole(phone, Role.WORKER).isPresent()) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "A partner account already exists for this phone number. Sign in instead.");
        }
        String photo = normalizePhoto(x.profileImage());
        return otpChallenge(phone, x.name().trim(), x.gender(), x.dob(), photo, PartnerOtpPurpose.SIGNUP);
    }

    @PostMapping("/partner/otp/login/start")
    public Map<String, Object> startPartnerLogin(@Valid @RequestBody PartnerLoginStart x) {
        String phone = normalizePhone(x.phone());
        users.findByPhoneAndRole(phone, Role.WORKER)
                .filter(UserAccount::isEnabled)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "No partner account found for this phone number. Create your account first."));
        return otpChallenge(phone, null, null, null, null, PartnerOtpPurpose.LOGIN);
    }

    @PostMapping("/partner/otp/verify")
    public Map<String, Object> verifyPartnerOtp(@Valid @RequestBody PartnerOtpVerify x) {
        String phone = normalizePhone(x.phone());
        PartnerOtpPurpose purpose = PartnerOtpPurpose.valueOf(x.purpose().toUpperCase());
        PartnerOtp challenge = partnerOtps
                .findTopByPhoneAndPurposeAndConsumedFalseOrderByIdDesc(phone, purpose)
                .filter(PartnerOtp::valid)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "OTP is invalid or expired. Request a new OTP."));
        challenge.attempt();
        if (!encoder.matches(x.otp(), challenge.getOtpHash())) {
            partnerOtps.save(challenge);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Incorrect OTP. Try again.");
        }
        UserAccount user = purpose == PartnerOtpPurpose.SIGNUP
                ? createPartner(challenge)
                : users.findByPhoneAndRole(phone, Role.WORKER)
                        .filter(UserAccount::isEnabled)
                        .orElseThrow(() -> new ResponseStatusException(
                                HttpStatus.NOT_FOUND, "No partner account found for this phone number."));
        challenge.consume();
        partnerOtps.save(challenge);
        return sessionResponse(user, DEFAULT_SESSION);
    }

    @PostMapping("/forgot-password")
    public Map<String, Object> forgot(@Valid @RequestBody EmailRequest x) {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "If the account exists, a reset email has been queued.");
        users.findByEmailIgnoreCase(x.email()).ifPresent(u -> {
            ResetToken reset = resets.save(new ResetToken(token(), u, Instant.now().plus(Duration.ofMinutes(30))));
            if (mailEnabled && mailSender.getIfAvailable() != null
                    && u.getEmail() != null && !u.getEmail().isBlank()) {
                try {
                    SimpleMailMessage email = new SimpleMailMessage();
                    email.setFrom(mailFrom);
                    email.setTo(u.getEmail());
                    email.setSubject("MaidItQuick password reset");
                    email.setText("Use this link to reset your MaidItQuick password: "
                            + "http://localhost:8080/reset-password?token=" + reset.getToken());
                    mailSender.getIfAvailable().send(email);
                } catch (RuntimeException ignored) {
                    log.warn("Failed to send reset email for {}", maskEmail(u.getEmail()));
                }
            } else {
                log.info("Password reset token for {}: {}", maskEmail(u.getEmail()), reset.getToken());
                response.put("devResetToken", reset.getToken());
            }
        });
        return response;
    }

    @PostMapping("/reset-password")
    public Map<String, String> reset(@Valid @RequestBody Reset x) {
        ResetToken r = resets.findByToken(x.token())
                .filter(ResetToken::valid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid or expired reset token"));
        r.getUser().setPasswordHash(encoder.encode(x.password()));
        r.use();
        users.save(r.getUser());
        resets.save(r);
        return Map.of("message", "Password updated");
    }

    private Map<String, Object> sessionResponse(UserAccount user, Duration lifetime) {
        String token = token();
        sessions.save(new Session(token, user, Instant.now().plus(lifetime)));
        return Map.of("token", token, "role", user.getRole(), "name", user.getName());
    }

    private String bearerToken(String authorization) {
        return authorization == null ? "" : authorization.replaceFirst("(?i)^Bearer\\s+", "").trim();
    }

    private String token() {
        byte[] b = new byte[48];
        random.nextBytes(b);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }

    private Map<String, Object> otpChallenge(String phone, String name, String gender,
                                             LocalDate dob, String profileImage, PartnerOtpPurpose purpose) {
        String otp = String.format("%06d", random.nextInt(1_000_000));
        partnerOtps.save(new PartnerOtp(
                phone, name, gender, dob, profileImage, purpose, encoder.encode(otp),
                Instant.now().plus(Duration.ofMinutes(10))));
        Map<String, Object> response = new HashMap<>(Map.of(
                "message", "OTP sent", "phone", phone, "expiresInSeconds", 600));
        if (!smsEnabled) {
            response.put("devOtp", otp);
        }
        return response;
    }

    private UserAccount createPartner(PartnerOtp challenge) {
        String phone = challenge.getPhone();
        users.findByPhoneAndRole(phone, Role.WORKER)
                .ifPresent(u -> {
                    throw new ResponseStatusException(
                            HttpStatus.CONFLICT,
                            "A partner account already exists for this phone number. Sign in instead.");
                });
        UserAccount user = new UserAccount(challenge.getName(), "", encoder.encode(token()), phone, Role.WORKER);
        user.setEmailNotifications(false);
        if (challenge.getGender() != null && !challenge.getGender().isBlank()) {
            user.setGender(challenge.getGender());
        }
        if (challenge.getDob() != null) {
            user.setDob(challenge.getDob());
        }
        if (challenge.getProfileImage() != null && !challenge.getProfileImage().isBlank()) {
            user.setProfileImage(challenge.getProfileImage());
        }
        return users.save(user);
    }

    private static String normalizePhoto(String profileImage) {
        if (profileImage == null || profileImage.isBlank()) return null;
        try {
            return ProfilePhotos.normalize(profileImage);
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, e.getMessage());
        }
    }

    private static String maskEmail(String email) {
        if (email == null || email.isBlank()) return "unknown";
        int at = email.indexOf('@');
        if (at <= 1) return "***" + email.substring(at);
        return email.substring(0, 1) + "***" + email.substring(at);
    }

    private String normalizePhone(String raw) {
        String compact = raw.trim().replaceAll("[\\s\\-().]", "");
        if (compact.startsWith("00")) {
            compact = "+" + compact.substring(2);
        }
        if (!compact.startsWith("+") && compact.matches("\\d{10}")) {
            compact = "+91" + compact;
        }
        if (!compact.matches("\\+[1-9]\\d{7,14}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a valid phone number with country code.");
        }
        return compact;
    }

    public record Register(
            @NotBlank String name,
            @NotBlank @Email String email,
            @Size(min = 8, max = 72) String password,
            @Pattern(regexp = "customer|worker", flags = Pattern.Flag.CASE_INSENSITIVE) String role) {}

    public record Login(@NotBlank @Email String email, @NotBlank String password) {}

    public record CustomerOtpStart(@NotBlank String phone) {}

    public record CustomerOtpVerify(
            @NotBlank String phone, @NotBlank @Pattern(regexp = "\\d{6}") String otp) {}

    public record CustomerSignupStart(
            @NotBlank String name,
            @NotBlank String phone,
            @Email String email) {}

    public record CustomerSignupVerify(
            @NotBlank String name,
            @NotBlank String phone,
            @Email String email,
            @NotBlank @Pattern(regexp = "\\d{6}") String otp) {}

    public record PartnerSignupStart(
            @NotBlank(message = "Enter your name.") String name,
            @NotBlank(message = "Enter a valid phone number.") String phone,
            @Pattern(regexp = "MALE|FEMALE|OTHER|PREFER_NOT_TO_SAY", flags = Pattern.Flag.CASE_INSENSITIVE,
                    message = "Select a valid gender.") String gender,
            LocalDate dob,
            @Size(max = 2_900_000, message = "The photo is too large.") String profileImage) {}

    public record PartnerLoginStart(@NotBlank String phone) {}

    public record PartnerOtpVerify(
            @NotBlank String phone,
            @NotBlank @Pattern(regexp = "signup|login", flags = Pattern.Flag.CASE_INSENSITIVE) String purpose,
            @NotBlank @Pattern(regexp = "\\d{6}") String otp) {}

    public record EmailRequest(@NotBlank @Email String email) {}

    public record Reset(@NotBlank String token, @Size(min = 8, max = 72) String password) {}
}
