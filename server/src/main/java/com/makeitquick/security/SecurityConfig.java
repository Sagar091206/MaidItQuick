package com.makeitquick.security;

import jakarta.servlet.DispatcherType;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * The single security filter chain for the merged app. Both the mobile realm
 * ({@code /api/v1/**}) and the admin realm ({@code /api/v1/admin/**}) share one
 * stateless chain, one {@link JwtService} issuer and one identity model
 * ({@link UserAccount}). The admin SPA is served as static content.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    /** Paths reachable without authentication. */
    private static final String[] PUBLIC = {
            // mobile public surface
            "/app/**",
            "/error",
            "/api/auth/**",
            "/api/v1/auth/**",
            "/api/customer/signup/**",
            "/api/health",
            "/api/maps/browser-key",
            "/api/availability/**",
            "/api/services/**",
            // admin public auth surface
            "/api/v1/admin/login",
            "/api/v1/admin/refresh-token",
            "/api/v1/admin/auth/login",
            "/api/v1/admin/auth/refresh",
            "/api/v1/admin/auth/logout",
            "/api/v1/admin/forgot-password",
            "/api/v1/admin/reset-password",
            // infra + admin SPA
            "/uploads/**",
            "/actuator/health",
            "/actuator/**",
            "/swagger-ui/**",
            "/swagger-ui.html",
            "/v3/api-docs/**",
            "/",
            "/index.html",
            "/login.html",
            "/dashboard.html",
            "/forgot-password.html",
            "/reset-password.html",
            "/css/**",
            "/js/**",
            "/assets/**",
            "/favicon.ico",
            "/manifest.webmanifest",
            "/service-worker.js"
    };

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http,
                                    SessionAuthenticationFilter sessionFilter,
                                    com.maiditquick.admin.security.RateLimitFilter rateLimit) throws Exception {
        return http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(Customizer.withDefaults())
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        // Preserve the status and message raised by API controllers.
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
                        .requestMatchers(PUBLIC).permitAll()
                        .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                        .requestMatchers("/api/**").authenticated()
                        // Static admin SPA assets and anything else.
                        .anyRequest().permitAll())
                .exceptionHandling(e -> e.authenticationEntryPoint((request, response, ex) -> {
                    response.setStatus(401);
                    response.setContentType("application/json");
                    response.setCharacterEncoding("UTF-8");
                    response.getWriter().write(
                            "{\"success\":false,\"status\":401,\"message\":\"Authentication required\"}");
                }))
                .addFilterBefore(rateLimit, UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(sessionFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource(@Value("${app.cors-origin}") String origin) {
        CorsConfiguration c = new CorsConfiguration();
        c.setAllowedOrigins(List.of(origin));
        c.setAllowedMethods(List.of("GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"));
        c.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        c.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", c);
        return source;
    }
}
