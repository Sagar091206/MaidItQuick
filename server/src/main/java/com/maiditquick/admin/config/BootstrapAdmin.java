package com.maiditquick.admin.config;
import com.maiditquick.admin.admin.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.*;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Configuration
public class BootstrapAdmin {

  private static final Logger log = LoggerFactory.getLogger(BootstrapAdmin.class);

  static final Map<String, String> PERMISSIONS = new LinkedHashMap<>();

  static {
    PERMISSIONS.put("DASHBOARD_VIEW", "View dashboard");
    PERMISSIONS.put("AUTH_PROFILE", "Access own admin profile");
    PERMISSIONS.put("USERS_READ", "View users");
    PERMISSIONS.put("USERS_WRITE", "Manage user state");
    PERMISSIONS.put("ROLES_READ", "View roles");
    PERMISSIONS.put("ROLES_WRITE", "Manage roles");
    PERMISSIONS.put("SERVICES_READ", "View services");
    PERMISSIONS.put("SERVICES_WRITE", "Manage services");
    PERMISSIONS.put("CATEGORIES_READ", "View categories");
    PERMISSIONS.put("CATEGORIES_WRITE", "Manage categories");
    PERMISSIONS.put("BOOKINGS_READ", "View bookings");
    PERMISSIONS.put("BOOKINGS_WRITE", "Manage bookings");
    PERMISSIONS.put("PARTNERS_READ", "View partner KYC");
    PERMISSIONS.put("PARTNERS_WRITE", "Approve and manage partners");
    PERMISSIONS.put("CUSTOMERS_READ", "View customers");
    PERMISSIONS.put("CUSTOMERS_WRITE", "Manage customers");
    PERMISSIONS.put("PAYMENTS_READ", "View payments");
    PERMISSIONS.put("PAYMENTS_WRITE", "Manage payments");
    PERMISSIONS.put("REVIEWS_READ", "View reviews");
    PERMISSIONS.put("REVIEWS_WRITE", "Moderate reviews");
    PERMISSIONS.put("NOTIFICATIONS_READ", "View notifications");
    PERMISSIONS.put("NOTIFICATIONS_WRITE", "Send notifications");
    PERMISSIONS.put("SETTINGS_READ", "View settings");
    PERMISSIONS.put("SETTINGS_WRITE", "Manage settings");
    PERMISSIONS.put("REPORTS_VIEW", "View reports");
    PERMISSIONS.put("AUDIT_READ", "View audit logs");
    PERMISSIONS.put("ADMINS_MANAGE", "Manage administrators");
    PERMISSIONS.put("SETTLEMENTS_READ", "View financial settlements & payouts");
    PERMISSIONS.put("SETTLEMENTS_WRITE", "Approve payouts and commission rates");
    PERMISSIONS.put("OVERRIDES_WRITE", "Manual booking overrides (cancel, reassign, refund)");
    PERMISSIONS.put("DISPUTES_READ", "View support disputes");
    PERMISSIONS.put("DISPUTES_WRITE", "Resolve disputes and upload logs");
  }

  @Bean
  @Transactional
  CommandLineRunner bootstrap(
      AdminRepository admins,
      AdminRoleRepository roles,
      AdminPermissionRepository permissions,
      PasswordEncoder encoder,
      @Value("${app.bootstrap.email}") String email,
      @Value("${app.bootstrap.password}") String password,
      @Value("${app.bootstrap.support-email}") String supportEmail,
      @Value("${app.bootstrap.support-password}") String supportPassword) {
    return a -> {
      Map<String, AdminPermission> seeded = new HashMap<>();
      PERMISSIONS.forEach((code, desc) -> {
        AdminPermission p = permissions.findByCode(code)
            .orElseGet(() -> {
              AdminPermission created = new AdminPermission();
              created.setCode(code);
              created.setDescription(desc);
              return permissions.save(created);
            });
        seeded.put(code, p);
      });

      AdminRole superAdmin = roles.findByCode("SUPER_ADMIN").orElseGet(() -> {
        AdminRole r = new AdminRole();
        r.setCode("SUPER_ADMIN");
        r.setName("Super Administrator");
        return roles.save(r);
      });
      superAdmin.getPermissions().clear();
      superAdmin.getPermissions().addAll(seeded.values());
      roles.save(superAdmin);

      AdminRole admin = roles.findByCode("ADMIN").orElseGet(() -> {
        AdminRole r = new AdminRole();
        r.setCode("ADMIN");
        r.setName("Administrator");
        return roles.save(r);
      });
      admin.getPermissions().clear();
      admin.getPermissions().addAll(permissions.findByCodeIn(List.of(
          "DASHBOARD_VIEW", "AUTH_PROFILE", "USERS_READ", "USERS_WRITE", "SERVICES_READ", "SERVICES_WRITE",
          "CATEGORIES_READ", "CATEGORIES_WRITE", "BOOKINGS_READ", "BOOKINGS_WRITE",
          "PARTNERS_READ", "PARTNERS_WRITE", "CUSTOMERS_READ", "PAYMENTS_READ", "REVIEWS_READ",
          "NOTIFICATIONS_READ", "NOTIFICATIONS_WRITE", "SETTINGS_READ", "REPORTS_VIEW", "AUDIT_READ",
          "SETTLEMENTS_READ", "SETTLEMENTS_WRITE", "OVERRIDES_WRITE",
          "DISPUTES_READ", "DISPUTES_WRITE")));
      roles.save(admin);

      AdminRole viewer = roles.findByCode("VIEWER").orElseGet(() -> {
        AdminRole r = new AdminRole();
        r.setCode("VIEWER");
        r.setName("Viewer");
        return roles.save(r);
      });
      viewer.getPermissions().clear();
      viewer.getPermissions().addAll(permissions.findByCodeIn(List.of(
          "DASHBOARD_VIEW", "AUTH_PROFILE", "USERS_READ", "SERVICES_READ", "CATEGORIES_READ",
          "BOOKINGS_READ", "PARTNERS_READ", "CUSTOMERS_READ", "PAYMENTS_READ", "REVIEWS_READ",
          "NOTIFICATIONS_READ", "SETTINGS_READ", "REPORTS_VIEW")));
      roles.save(viewer);

      AdminRole support = roles.findByCode("SUPPORT_OPERATOR").orElseGet(() -> {
        AdminRole r = new AdminRole();
        r.setCode("SUPPORT_OPERATOR");
        r.setName("Support Operator");
        return roles.save(r);
      });
      support.getPermissions().clear();
      support.getPermissions().addAll(permissions.findByCodeIn(List.of(
          "DASHBOARD_VIEW", "AUTH_PROFILE", "BOOKINGS_READ", "PARTNERS_READ", "CUSTOMERS_READ",
          "SETTLEMENTS_READ", "DISPUTES_READ", "NOTIFICATIONS_READ", "REPORTS_VIEW")));
      roles.save(support);

      if (!email.isBlank() && !password.isBlank()
          && admins.findByEmailIgnoreCase(email).isEmpty()) {
        Admin x = new Admin();
        x.setEmail(email);
        x.setDisplayName("Initial Administrator");
        x.setPasswordHash(encoder.encode(password));
        x.setRole(superAdmin);
        admins.save(x);
        log.info("Bootstrapped initial administrator {}", email);
      }

      AdminRole supportRole = support;
      if (!supportEmail.isBlank() && !supportPassword.isBlank()
          && admins.findByEmailIgnoreCase(supportEmail).isEmpty()) {
        Admin s = new Admin();
        s.setEmail(supportEmail);
        s.setDisplayName("Support Operator");
        s.setPasswordHash(encoder.encode(supportPassword));
        s.setRole(supportRole);
        admins.save(s);
        log.info("Bootstrapped support operator {}", supportEmail);
      }
    };
  }
}
