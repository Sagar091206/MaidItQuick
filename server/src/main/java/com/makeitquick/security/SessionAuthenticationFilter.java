package com.makeitquick.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Optional;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Converts a valid MakeItQuick bearer token (JWT or legacy session) into Spring Security authentication. */
@Component
public class SessionAuthenticationFilter extends OncePerRequestFilter {
    private final SessionResolver resolver;

    SessionAuthenticationFilter(SessionResolver resolver) {
        this.resolver = resolver;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        Optional<UserAccount> user = resolver.fromBearer(header);
        user.ifPresent(account -> {
            var authentication = new UsernamePasswordAuthenticationToken(
                    account.getEmail(),
                    null,
                    List.of(new SimpleGrantedAuthority("ROLE_" + account.getRole().name())));
            SecurityContextHolder.getContext().setAuthentication(authentication);
        });
        filterChain.doFilter(request, response);
    }
}
