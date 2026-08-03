package com.makeitquick.admin.admin;

import com.makeitquick.security.AdminPermissions;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.common.NotFoundException;
import com.makeitquick.admin.common.PageResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

/**
 * Administrators are {@link Role#ADMIN} {@link UserAccount}s on the unified
 * {@code users} table. The single ADMIN role carries every permission.
 */
@RestController
@RequestMapping("/api/v1/admin/admins")
public class AdminsController {

  private static final RoleInfo ADMIN_ROLE = new RoleInfo(1L, "ADMIN", "Administrator");

  private final UserRepository users;
  private final PasswordEncoder passwords;
  private final AuditService audit;

  public AdminsController(UserRepository users, PasswordEncoder passwords, AuditService audit) {
    this.users = users;
    this.passwords = passwords;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public ApiResponse<PageResponse<AdminView>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    var result = query.isBlank()
        ? users.findByRole(Role.ADMIN, pageable)
        : users.searchByRole(Role.ADMIN, query.toLowerCase(), pageable);
    return ApiResponse.ok(PageResponse.from(result, AdminView::from));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public ApiResponse<AdminView> get(@PathVariable long id) {
    return ApiResponse.ok(AdminView.from(find(id)));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public ApiResponse<AdminView> create(@Valid @RequestBody Create body, HttpServletRequest req) {
    if (users.existsByEmailIgnoreCase(body.email().trim())) {
      throw new IllegalArgumentException("An administrator with this email already exists");
    }
    UserAccount a = new UserAccount(body.displayName().trim(), body.email().trim(),
        passwords.encode(body.password()), Role.ADMIN);
    a.setEnabled(body.enabled() == null || body.enabled());
    UserAccount saved = users.save(a);
    audit.record("ADMIN_CREATED", "ADMINS", String.valueOf(saved.getId()), null,
        "{\"email\":\"" + saved.getEmail() + "\",\"role\":\"ADMIN\"}", req);
    return ApiResponse.created(AdminView.from(saved));
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public ApiResponse<AdminView> update(@PathVariable long id, @Valid @RequestBody Update body, HttpServletRequest req) {
    UserAccount a = find(id);
    String before = "{\"email\":\"" + a.getEmail() + "\",\"role\":\"ADMIN\",\"enabled\":" + a.isEnabled() + "}";
    a.setName(body.displayName().trim());
    if (body.enabled() != null) {
      a.setEnabled(body.enabled());
    }
    if (body.password() != null && !body.password().isBlank()) {
      a.setPasswordHash(passwords.encode(body.password()));
    }
    UserAccount saved = users.save(a);
    audit.record("ADMIN_UPDATED", "ADMINS", String.valueOf(id), before,
        "{\"email\":\"" + saved.getEmail() + "\",\"role\":\"ADMIN\",\"enabled\":" + saved.isEnabled() + "}", req);
    return ApiResponse.ok(AdminView.from(saved));
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public ApiResponse<AdminView> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange body, HttpServletRequest req) {
    UserAccount a = find(id);
    if (!body.enabled() && currentAdminId() == id) {
      throw new IllegalArgumentException("You cannot disable your own account");
    }
    if (!body.enabled() && users.countByRole(Role.ADMIN) <= 1) {
      throw new IllegalArgumentException("At least one active ADMIN must remain");
    }
    a.setEnabled(body.enabled());
    UserAccount saved = users.save(a);
    audit.record("ADMIN_STATUS_CHANGED", "ADMINS", String.valueOf(id), null,
        "{\"enabled\":" + saved.isEnabled() + "}", req);
    return ApiResponse.ok(AdminView.from(saved));
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    UserAccount a = find(id);
    if (currentAdminId() == id) {
      throw new IllegalArgumentException("You cannot delete your own account");
    }
    if (a.isEnabled() && users.countByRole(Role.ADMIN) <= 1) {
      throw new IllegalArgumentException("At least one active ADMIN must remain");
    }
    a.setEnabled(false);
    users.save(a);
    audit.record("ADMIN_DELETED", "ADMINS", String.valueOf(id), null, null, req);
  }

  private long currentAdminId() {
    try {
      return Long.parseLong(SecurityContextHolder.getContext().getAuthentication().getName());
    } catch (Exception e) {
      return -1;
    }
  }

  private UserAccount find(long id) {
    return users.findById(id).orElseThrow(() -> NotFoundException.of("Admin", id));
  }

  public record Create(
      @NotBlank @Email @Size(max = 255) String email,
      @NotBlank @Size(min = 12, max = 128) String password,
      @NotBlank @Size(max = 160) String displayName,
      @NotNull Long roleId,
      Boolean enabled) {
  }

  public record Update(
      @NotBlank @Size(max = 160) String displayName,
      @NotNull Long roleId,
      Boolean enabled,
      @Size(min = 12, max = 128) String password) {
  }

  public record StatusChange(
      @NotNull Boolean enabled) {
  }

  public record RoleInfo(Long id, String code, String name) {
  }

  public record AdminView(Long id, String email, String displayName, boolean enabled,
                          Instant lockedUntil, int failedAttempts, RoleInfo role,
                          List<String> permissions) {
    static AdminView from(UserAccount u) {
      return new AdminView(u.getId(), u.getEmail(), u.getName(), u.isEnabled(),
          u.getLockedUntil(), u.getFailedAttempts(), ADMIN_ROLE, AdminPermissions.ALL);
    }
  }
}
