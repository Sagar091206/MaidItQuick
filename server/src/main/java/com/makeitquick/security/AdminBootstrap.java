package com.makeitquick.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Creates the first administrator only when credentials are supplied through environment settings.
 * It never overwrites an existing user.
 */
@Configuration
public class AdminBootstrap {
    @Bean
    CommandLineRunner createInitialAdmin(
            UserRepository users,
            @Value("${app.admin.email:}") String email,
            @Value("${app.admin.password:}") String password,
            @Value("${app.admin.name:MakeItQuick Admin}") String name) {
        return arguments -> {
            if (email.isBlank() || password.isBlank() || users.findByEmailIgnoreCase(email).isPresent()) {
                return;
            }
            if (password.length() < 12) {
                throw new IllegalStateException("APP_ADMIN_PASSWORD must contain at least 12 characters");
            }
            users.save(new UserAccount(name, email.trim().toLowerCase(),
                    new BCryptPasswordEncoder(12).encode(password), Role.ADMIN));
        };
    }
}
