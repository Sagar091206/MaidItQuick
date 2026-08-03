package com.makeitquick;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;

/**
 * Single monolith serving the mobile app and the admin web module from one
 * process and one database. The admin controllers, services, and repositories
 * live under {@code com.makeitquick.admin}, so the default component, entity,
 * and JPA repository scans all pick them up — no module-specific scan config or
 * bean-name generator is needed. {@code UserDetailsServiceAutoConfiguration}
 * stays excluded because the unified security stack provides its own
 * user-details service.
 */
@SpringBootApplication(exclude = {
        UserDetailsServiceAutoConfiguration.class
})
public class MakeItQuickApplication { public static void main(String[] args) { SpringApplication.run(MakeItQuickApplication.class, args); } }
