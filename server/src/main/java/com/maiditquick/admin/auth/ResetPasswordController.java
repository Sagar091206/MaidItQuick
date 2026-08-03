package com.maiditquick.admin.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * US 1.3 reset-password endpoint.
 * Public (see SecurityConfig). Redeems the emailed token and sets a new
 * password; any invalid/used/expired token gets a generic 400.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class ResetPasswordController {

    private final ResetPasswordService service;

    public ResetPasswordController(ResetPasswordService service) {
        this.service = service;
    }

    @PostMapping("/reset-password")
    public ResetPasswordResponse resetPassword(
            @Valid @RequestBody ResetPasswordRequest request,
            HttpServletRequest http) {
        return service.redeem(request, http);
    }
}
