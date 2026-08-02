package com.maiditquick.admin.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * US 1.2 forgot-password endpoint.
 * Public (see SecurityConfig). Always answers HTTP 200 with the generic
 * message — the caller can never tell whether the email is registered.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class ForgotPasswordController {

    private final ForgotPasswordService service;

    public ForgotPasswordController(ForgotPasswordService service) {
        this.service = service;
    }

    @PostMapping("/forgot-password")
    public ForgotPasswordResponse forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request,
            HttpServletRequest http) {
        return service.requestReset(request, http);
    }
}
