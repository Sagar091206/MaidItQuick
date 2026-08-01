package com.makeitquick.security;

import com.makeitquick.security.dto.AuthV1Response;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Customer authentication endpoints for the unified mobile flow.
 *
 * <p>{@code send-otp} issues a short-lived OTP, {@code verify-otp} either signs
 * an existing customer in or returns a pending registration token, and
 * {@code complete-profile} creates the account for a new customer.</p>
 */
@RestController
@RequestMapping("/api/v1/auth")
@CrossOrigin(origins = "*")
public class AuthV1Controller {
    private final AuthV1Service auth;

    AuthV1Controller(AuthV1Service auth) {
        this.auth = auth;
    }

    @PostMapping("/send-otp")
    public AuthV1Response sendOtp(@Valid @RequestBody SendOtpRequest request) {
        return auth.sendOtp(request.phone());
    }

    @PostMapping("/verify-otp")
    public AuthV1Response verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
        return auth.verifyOtp(request.phone(), request.otp());
    }

    @PostMapping("/complete-profile")
    public AuthV1Response completeProfile(@Valid @RequestBody CompleteProfileRequest request) {
        return auth.completeProfile(
                request.pendingToken(),
                request.name(),
                request.email(),
                request.gender(),
                request.dob(),
                request.profileImage());
    }

    public record SendOtpRequest(
            @NotBlank(message = "Enter a valid 10-digit mobile number.") String phone) {}

    public record VerifyOtpRequest(
            @NotBlank(message = "Enter the six-digit OTP") String phone,
            @NotBlank(message = "Enter the six-digit OTP")
            @Pattern(regexp = "\\d{6}", message = "Enter the six-digit OTP") String otp) {}

    public record CompleteProfileRequest(
            @NotBlank(message = "Verification is missing. Request a new OTP.") String pendingToken,
            @NotBlank(message = "Enter your full name.") String name,
            @Email(message = "Enter a valid email address") String email,
            @Pattern(regexp = "MALE|FEMALE|OTHER|PREFER_NOT_TO_SAY", flags = Pattern.Flag.CASE_INSENSITIVE)
                    String gender,
            LocalDate dob,
            @Size(max = 2_900_000, message = "The photo is too large.")
            String profileImage) {}
}
