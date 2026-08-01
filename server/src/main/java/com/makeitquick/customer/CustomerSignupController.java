package com.makeitquick.customer;

import com.makeitquick.security.AuthService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.Map;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Canonical customer signup endpoints.
 *
 * <p>Reuses the OTP infrastructure through {@link AuthService}; the legacy
 * {@code /api/auth/customer/signup/**} routes remain available for backward
 * compatibility.</p>
 */
@RestController
@RequestMapping("/api/customer")
@CrossOrigin(origins = "*")
public class CustomerSignupController {
    private final AuthService auth;

    CustomerSignupController(AuthService auth) {
        this.auth = auth;
    }

    @PostMapping("/signup/start")
    public Map<String, Object> start(@Valid @RequestBody SignupStart request) {
        return auth.startCustomerSignup(request.name(), request.phone(), request.email());
    }

    @PostMapping("/signup/verify")
    public Map<String, Object> verify(@Valid @RequestBody SignupVerify request) {
        return auth.verifyCustomerSignup(request.name(), request.phone(), request.email(), request.otp());
    }

    public record SignupStart(
            @NotBlank String name,
            @NotBlank String phone,
            @Email String email) {}

    public record SignupVerify(
            @NotBlank String name,
            @NotBlank String phone,
            @Email String email,
            @NotBlank @Pattern(regexp = "\\d{6}") String otp) {}
}
