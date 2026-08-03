package com.maiditquick.admin.admin;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.common.PageResponse;
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

@RestController
@RequestMapping("/api/v1/admin/admins")
public class AdminsController {

  private final AdminRepository admins;
  private final AdminRoleRepository roles;
  private final PasswordEncoder passwords;
  private final AuditService audit;

  public AdminsController(AdminRepository admins, AdminRoleRepository roles,
                          PasswordEncoder passwords, AuditService audit) {
    this.admins = admins;
    this.roles = roles;
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
        ? admins.findAll(pageable)
        : admins.findByEmailIgnoreCaseContainingOrDisplayNameIgnoreCaseContaining(
            query.toLowerCase(), query.toLowerCase(), pageable);
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
    if (admins.findByEmailIgnoreCase(body.email().trim()).isPresent()) {
      throw new IllegalArgumentException("An administrator with this email already exists");
    }
    Admin a = new Admin();
    a.setEmail(body.email().trim());
    a.setPasswordHash(passwords.encode(body.password()));
    a.setDisplayName(body.displayName().trim());
    a.setEnabled(body.enabled() == null || body.enabled());
    a.setRole(findRole(body.roleId()));
    Admin saved = admins.save(a);
    audit.record("ADMIN_CREATED", "ADMINS", String.valueOf(saved.getId()), null,
        "{\"email\":\"" + saved.getEmail() + "\",\"role\":\"" + saved.getRole().getCode() + "\"}", req);
    return ApiResponse.created(AdminView.from(saved));
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public ApiResponse<AdminView> update(@PathVariable long id, @Valid @RequestBody Update body, HttpServletRequest req) {
    Admin a = find(id);
    String before = "{\"email\":\"" + a.getEmail() + "\",\"role\":\"" + a.getRole().getCode() + "\",\"enabled\":" + a.isEnabled() + "}";
    a.setDisplayName(body.displayName().trim());
    a.setRole(findRole(body.roleId()));
    if (body.enabled() != null) {
      a.setEnabled(body.enabled());
    }
    if (body.password() != null && !body.password().isBlank()) {
      a.setPasswordHash(passwords.encode(body.password()));
    }
    Admin saved = admins.save(a);
    audit.record("ADMIN_UPDATED", "ADMINS", String.valueOf(id), before,
        "{\"email\":\"" + saved.getEmail() + "\",\"role\":\"" + saved.getRole().getCode() + "\",\"enabled\":" + saved.isEnabled() + "}", req);
    return ApiResponse.ok(AdminView.from(saved));
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public ApiResponse<AdminView> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange body, HttpServletRequest req) {
    Admin a = find(id);
    if (!body.enabled() && currentAdminId() == id) {
      throw new IllegalArgumentException("You cannot disable your own account");
    }
    if (!body.enabled() && "SUPER_ADMIN".equals(a.getRole().getCode()) && admins.countByRoleCodeAndEnabledTrue("SUPER_ADMIN") <= 1) {
      throw new IllegalArgumentException("At least one active SUPER_ADMIN must remain");
    }
    a.setEnabled(body.enabled());
    Admin saved = admins.save(a);
    audit.record("ADMIN_STATUS_CHANGED", "ADMINS", String.valueOf(id), null,
        "{\"enabled\":" + saved.isEnabled() + "}", req);
    return ApiResponse.ok(AdminView.from(saved));
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('ADMINS_MANAGE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    Admin a = find(id);
    if (currentAdminId() == id) {
      throw new IllegalArgumentException("You cannot delete your own account");
    }
    if ("SUPER_ADMIN".equals(a.getRole().getCode()) && a.isEnabled()
        && admins.countByRoleCodeAndEnabledTrue("SUPER_ADMIN") <= 1) {
      throw new IllegalArgumentException("At least one active SUPER_ADMIN must remain");
    }
    admins.delete(a);
    audit.record("ADMIN_DELETED", "ADMINS", String.valueOf(id), null, null, req);
  }

  private long currentAdminId() {
    try {
      return Long.parseLong(SecurityContextHolder.getContext().getAuthentication().getName());
    } catch (Exception e) {
      return -1;
    }
  }

  private Admin find(long id) {
    return admins.findById(id).orElseThrow(() -> NotFoundException.of("Admin", id));
  }

  private AdminRole findRole(long id) {
    return roles.findById(id).orElseThrow(() -> NotFoundException.of("Role", id));
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

  public record AdminView(Long id, String email, String displayName, boolean enabled,
                          Instant lockedUntil, int failedAttempts, AdminRole role,
                          List<String> permissions) {
    static AdminView from(Admin a) {
      return new AdminView(a.getId(), a.getEmail(), a.getDisplayName(), a.isEnabled(),
          a.getLockedUntil(), a.getFailedAttempts(), a.getRole(),
          a.getRole().getPermissions().stream().map(AdminPermission::getCode).toList());
    }
  }
}
