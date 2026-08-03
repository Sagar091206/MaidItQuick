package com.makeitquick.admin.security;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Brute-force and abuse guards on the public POST endpoints (US 1.1 + 1.2):
 *  - per-IP window: max 20 auth/reset POSTs per minute
 *  - forgot-password: max 5 requests per email per IP per hour -> 429
 * The request body is cached and re-exposed so downstream controllers can
 * still deserialize it.
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private static final int MAX_AUTH_POSTS_PER_MINUTE = 20;
    private static final int MAX_RESET_REQUESTS_PER_HOUR = 5;
    private static final int MAX_WINDOWS = 10_000;
    private static final Duration IP_WINDOW = Duration.ofMinutes(1);
    private static final Duration RESET_WINDOW = Duration.ofHours(1);

    private final ConcurrentMap<String, Window> ipWindows = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, Window> resetWindows = new ConcurrentHashMap<>();
    private final ObjectMapper json = new ObjectMapper();

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !(request.getMethod().equals("POST")
                && request.getRequestURI()
                        .matches(".*/(auth/login|auth/refresh|login|refresh-token|forgot-password|reset-password)$"));
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain chain)
            throws ServletException, IOException {

        HttpServletRequest effective = request;

        if (request.getRequestURI().endsWith("/forgot-password")) {
            byte[] body = readBody(request);
            effective = new CachedBodyHttpServletRequest(request, body);

            String email = extractEmail(body);
            if (email != null) {
                String key = email.trim().toLowerCase(Locale.ROOT) + "|" + request.getRemoteAddr();
                Window window = window(resetWindows, key, RESET_WINDOW);
                if (window.calls > MAX_RESET_REQUESTS_PER_HOUR) {
                    writeTooManyRequests(response, "Too many password reset requests. Please try again later.");
                    return;
                }
            }
        }

        String ipKey = request.getRemoteAddr() + ":" + request.getRequestURI();
        if (window(ipWindows, ipKey, IP_WINDOW).calls > MAX_AUTH_POSTS_PER_MINUTE) {
            writeTooManyRequests(response, "Too many requests. Please try again later.");
            return;
        }

        chain.doFilter(effective, response);
    }

    private Window window(ConcurrentMap<String, Window> map, String key, Duration span) {
        Window w = map.compute(key, (k, v) ->
                v == null || v.started.plus(span).isBefore(Instant.now())
                        ? new Window(Instant.now(), 1)
                        : new Window(v.started, v.calls + 1));
        // Opportunistic eviction of expired windows so the maps cannot grow
        // unboundedly under varied IP/URI traffic.
        if (map.size() > MAX_WINDOWS) {
            Instant now = Instant.now();
            map.entrySet().removeIf(e -> e.getValue().started.plus(span).isBefore(now));
        }
        return w;
    }

    private byte[] readBody(HttpServletRequest request) throws IOException {
        if (request.getContentLengthLong() <= 0) {
            return new byte[0];
        }
        return request.getInputStream().readAllBytes();
    }

    private String extractEmail(byte[] body) {
        if (body.length == 0) {
            return null;
        }
        try {
            JsonNode node = json.readTree(body);
            JsonNode email = node.get("email");
            return email == null ? null : email.asText(null);
        } catch (Exception ignored) {
            return null;
        }
    }

    private void writeTooManyRequests(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(
                "{\"success\":false,\"status\":429,\"message\":\"" + message + "\"}");
    }

    private record Window(Instant started, int calls) {
    }
}
