package com.makeitquick.admin.config;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.*;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;

@Configuration
public class BootstrapAdmin {

  private static final Logger log = LoggerFactory.getLogger(BootstrapAdmin.class);

  @Bean
  @Transactional
  CommandLineRunner bootstrap(
      UserRepository users,
      PasswordEncoder encoder,
      @Value("${app.bootstrap.email}") String email,
      @Value("${app.bootstrap.password}") String password,
      @Value("${app.bootstrap.support-email}") String supportEmail,
      @Value("${app.bootstrap.support-password}") String supportPassword) {
    return a -> {
      if (!email.isBlank() && !password.isBlank()
          && users.findByEmailIgnoreCase(email).isEmpty()) {
        users.save(new UserAccount("Initial Administrator", email, encoder.encode(password), Role.ADMIN));
        log.info("Bootstrapped initial administrator {}", email);
      }
      if (!supportEmail.isBlank() && !supportPassword.isBlank()
          && users.findByEmailIgnoreCase(supportEmail).isEmpty()) {
        users.save(new UserAccount("Support Operator", supportEmail, encoder.encode(supportPassword), Role.ADMIN));
        log.info("Bootstrapped support operator {}", supportEmail);
      }
    };
  }
}
