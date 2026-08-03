package com.makeitquick;

import com.maiditquick.admin.config.AdminBeanNameGenerator;
import com.maiditquick.admin.config.AdminModuleConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * Merged monolith serving the mobile app (com.makeitquick.*) and the admin web
 * module (com.maiditquick.admin.*) from one process and one database (Phase 2).
 *
 * <p>Persistence uses Spring Boot auto-configuration for the single datasource /
 * entity manager factory. {@code @EntityScan} covers both modules' entities and
 * {@code @EnableJpaRepositories} registers both modules' repositories, using the
 * package-aware {@link AdminBeanNameGenerator} so the many same-named admin and
 * mobile repositories do not collide. {@code UserDetailsServiceAutoConfiguration}
 * stays excluded because both modules provide their own user-details services.
 */
@SpringBootApplication(exclude = {
        UserDetailsServiceAutoConfiguration.class
})
@EntityScan(basePackages = {"com.makeitquick", "com.maiditquick.admin"})
@EnableJpaRepositories(
        basePackages = {"com.makeitquick", "com.maiditquick.admin"},
        nameGenerator = AdminBeanNameGenerator.class)
@Import(AdminModuleConfig.class)
public class MakeItQuickApplication { public static void main(String[] args) { SpringApplication.run(MakeItQuickApplication.class, args); } }
