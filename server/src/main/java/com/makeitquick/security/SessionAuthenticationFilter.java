package com.makeitquick.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Converts a valid MakeItQuick bearer session token into Spring Security authentication. */
@Component
public class SessionAuthenticationFilter extends OncePerRequestFilter {
    private final SessionRepository sessions;

    SessionAuthenticationFilter(SessionRepository sessions) {
        this.sessions = sessions;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.regionMatches(true, 0, "Bearer ", 0, 7)) {
            String token = header.substring(7).trim();
            sessions.findByToken(token)
                    .filter(Session::valid)
                    .ifPresent(session -> {
                        UserAccount user = session.getUser();
                        var authentication = new UsernamePasswordAuthenticationToken(
                                user.getEmail(),
                                null,
                                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name())));
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    });
        }
        filterChain.doFilter(request, response);
    }
}
