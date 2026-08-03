package com.maiditquick.admin.auth;

import java.time.Duration;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.maiditquick.admin.admin.Admin;
import com.maiditquick.admin.admin.AdminRepository;
import com.maiditquick.admin.auth.AuthExceptions.InvalidCredentialsException;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Legacy auth endpoints under /auth (kept for backward compatibility).
 * The canonical US 1.1 endpoints (/login, /refresh-token) live in
 * {@link PublicLoginController} and share the same service + cookie logic.
 */
@RestController
@RequestMapping("/api/v1/admin/auth")
public class AuthController {

    /** Refresh-cookie lifetime when "remember me" is checked (US 1.1: 7 days). */
    private static final Duration REMEMBER_ME_DAYS = Duration.ofDays(7);

    private final AuthService auth;
    private final AdminRepository admins;
    private final boolean cookieSecure;

    public AuthController(
            AuthService auth,
            AdminRepository admins,
            @Value("${app.cookie-secure}") boolean cookieSecure) {
        this.auth = auth;
        this.admins = admins;
        this.cookieSecure = cookieSecure;
    }

    @PostMapping("/login")
    public AuthService.Tokens login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest,
            HttpServletResponse response) {

        var tokens = auth.login(request.email(), request.password(), httpRequest);

        cookie(response, tokens.refreshToken(), Boolean.TRUE.equals(request.rememberMe()));

        return tokens;
    }

    @PostMapping("/refresh")
    public AuthService.Tokens refresh(
            @CookieValue(name = "admin_refresh", required = false) String token,
            HttpServletRequest request,
            HttpServletResponse response) {

        if (token == null) {
            throw new InvalidCredentialsException("Session expired");
        }

        var tokens = auth.refresh(token, request);

        cookie(response, tokens.refreshToken(), true);

        return tokens;
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(
            @CookieValue(name = "admin_refresh", required = false) String token,
            HttpServletResponse response) {

        if (token != null) {
            auth.logout(token);
        }

        cookie(response, "", false);
    }

    @GetMapping("/me")
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<Profile> me() {
        long id;
        try {
            id = Long.parseLong(SecurityContextHolder.getContext().getAuthentication().getName());
        } catch (Exception e) {
            throw new InvalidCredentialsException("Authentication required");
        }
        Admin admin = admins.findById(id).orElseThrow(() -> NotFoundException.of("Admin", id));
        return ApiResponse.ok(new Profile(
                admin.getId(),
                admin.getEmail(),
                admin.getDisplayName(),
                admin.isEnabled(),
                new RoleInfo(admin.getRole().getId(), admin.getRole().getCode(), admin.getRole().getName()),
                admin.getRole().getPermissions().stream().map(p -> p.getCode()).toList()));
    }

    @PostMapping("/change-password")
    @PreAuthorize("hasAuthority('AUTH_PROFILE')")
    public ApiResponse<Void> changePassword(
            @Valid @RequestBody ChangePassword body,
            @CookieValue(name = "admin_refresh", required = false) String token,
            HttpServletRequest request) {

        Admin admin = currentAdmin();
        auth.changePassword(admin, body.currentPassword(), body.newPassword(), token, request);

        return ApiResponse.ok("Password changed. All other devices were signed out.");
    }

    @GetMapping("/sessions")
    @PreAuthorize("hasAuthority('AUTH_PROFILE')")
    public ApiResponse<List<AuthService.SessionView>> sessions(
            @CookieValue(name = "admin_refresh", required = false) String token) {

        return ApiResponse.ok(auth.listSessions(currentAdminId(), token));
    }

    @PostMapping("/sessions/{id}/revoke")
    @PreAuthorize("hasAuthority('AUTH_PROFILE')")
    public ApiResponse<Void> revokeSession(
            @PathVariable long id,
            @CookieValue(name = "admin_refresh", required = false) String token,
            HttpServletRequest request,
            HttpServletResponse response) {

        boolean revokedCurrent = auth.revokeSession(currentAdminId(), id, token, request);

        if (revokedCurrent) {
            cookie(response, "", false);
            return ApiResponse.ok("Current session revoked — you have been signed out.");
        }
        return ApiResponse.ok("Session revoked.");
    }

    @PostMapping("/sign-out-everywhere")
    @PreAuthorize("hasAuthority('AUTH_PROFILE')")
    public ApiResponse<Void> signOutEverywhere(
            HttpServletRequest request,
            HttpServletResponse response) {

        Admin admin = currentAdmin();
        int revoked = auth.signOutEverywhere(admin, request);
        cookie(response, "", false);
        return ApiResponse.ok("Signed out on all devices (" + revoked + " session(s) revoked).");
    }

    private long currentAdminId() {
        try {
            return Long.parseLong(SecurityContextHolder.getContext().getAuthentication().getName());
        } catch (Exception e) {
            throw new InvalidCredentialsException("Authentication required");
        }
    }

    private Admin currentAdmin() {
        return admins.findById(currentAdminId()).orElseThrow(() -> NotFoundException.of("Admin", currentAdminId()));
    }

    public record ChangePassword(
            @NotBlank(message = "Current password is required") String currentPassword,
            @NotBlank(message = "New password is required")
            @Size(min = 12, max = 128, message = "New password must be 12 to 128 characters")
            String newPassword) {
    }

    public record RoleInfo(Long id, String code, String name) {
    }

    public record Profile(Long id, String email, String name, boolean enabled,
                          RoleInfo role, List<String> permissions) {
    }

    /**
     * Set the httpOnly refresh cookie.
     * Path is /api/v1/admin so both /auth/refresh and /refresh-token receive it.
     * "Remember me" -> 7-day persistent cookie; otherwise a session cookie
     * (no Max-Age), which the browser drops when the tab/session ends.
     */
    private void cookie(HttpServletResponse response, String value, boolean rememberMe) {

        ResponseCookie.ResponseCookieBuilder builder = ResponseCookie.from("admin_refresh", value)
                .httpOnly(true)
                .secure(cookieSecure)
                .sameSite("Strict")
                .path("/api/v1/admin");

        if (value.isEmpty()) {
            builder.maxAge(Duration.ZERO);
        } else if (rememberMe) {
            builder.maxAge(REMEMBER_ME_DAYS);
        }

        response.addHeader(HttpHeaders.SET_COOKIE, builder.build().toString());
    }
}
