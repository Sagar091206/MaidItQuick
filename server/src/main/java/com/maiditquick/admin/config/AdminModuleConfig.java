package com.maiditquick.admin.config;

import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

/**
 * Scans the admin module (com.maiditquick.admin.*) using the admin-prefixed
 * bean name generator so beans with simple names that collide with the mobile
 * module (SecurityConfig, AuthService, JwtService, BookingController, ...) stay
 * distinct in the shared application context.
 *
 * <p>The merged app class keeps {@code @SpringBootApplication}'s default scan of
 * {@code com.makeitquick} and imports this configuration explicitly; it must not
 * live under {@code com.makeitquick} or it would be picked up by the default scan
 * as a regular bean without the name generator.
 */
@Configuration
@ComponentScan(
        basePackages = "com.maiditquick.admin",
        nameGenerator = AdminBeanNameGenerator.class)
public class AdminModuleConfig {
}
