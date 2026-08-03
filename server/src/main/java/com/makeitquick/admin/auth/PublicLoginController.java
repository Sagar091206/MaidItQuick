package com.makeitquick.admin.auth;

import java.time.Duration;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.makeitquick.admin.auth.AuthExceptions.InvalidCredentialsException;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;

/**
 * Canonical US 1.1 authentication endpoints:
 *   POST /api/v1/admin/login         — email + password -> JWT pair
 *   POST /api/v1/admin/refresh-token — rotate the refresh cookie -> JWT pair
 *
 * Both are public (see SecurityConfig) and share AdminAuthService with the
 * legacy /auth/* endpoints. The refresh cookie is HttpOnly, SameSite=Strict,
 * scoped to /api/v1/admin, and is set/rotated/cleared on every response here.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class PublicLoginController {

    private static final Duration REMEMBER_ME_DAYS = Duration.ofDays(7);

    private final AdminAuthService auth;
    private final boolean cookieSecure;

    public PublicLoginController(
            AdminAuthService auth,
            @Value("${app.cookie-secure}") boolean cookieSecure) {
        this.auth = auth;
        this.cookieSecure = cookieSecure;
    }

    @PostMapping("/login")
    public AdminAuthService.Tokens login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest,
            HttpServletResponse response) {

        var tokens = auth.login(request.email(), request.password(), httpRequest);

        cookie(response, tokens.refreshToken(), Boolean.TRUE.equals(request.rememberMe()));

        return tokens;
    }

    @PostMapping("/refresh-token")
    public AdminAuthService.Tokens refreshToken(
            @CookieValue(name = "admin_refresh", required = false) String token,
            HttpServletRequest httpRequest,
            HttpServletResponse response) {

        if (token == null) {
            throw new InvalidCredentialsException("Session expired");
        }

        var tokens = auth.refresh(token, httpRequest);

        cookie(response, tokens.refreshToken(), true);

        return tokens;
    }

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
