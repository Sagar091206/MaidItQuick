package com.maiditquick.admin.roles;

import com.maiditquick.admin.admin.*;
import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.HashSet;
import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/roles")
public class RolesController {

  private final AdminRoleRepository roles;
  private final AdminPermissionRepository permissions;
  private final AdminRepository admins;
  private final AuditService audit;

  public RolesController(AdminRoleRepository roles, AdminPermissionRepository permissions,
                         AdminRepository admins, AuditService audit) {
    this.roles = roles;
    this.permissions = permissions;
    this.admins = admins;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('ROLES_READ')")
  public ApiResponse<List<AdminRole>> list() {
    return ApiResponse.ok(roles.findAll());
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('ROLES_READ')")
  public ApiResponse<AdminRole> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('ROLES_WRITE')")
  public ApiResponse<AdminRole> create(@Valid @RequestBody RoleRequest body, HttpServletRequest req) {
    if (roles.findByCode(body.code().trim().toUpperCase()).isPresent()) {
      throw new IllegalArgumentException("A role with this code already exists");
    }
    AdminRole r = new AdminRole();
    r.setCode(body.code().trim().toUpperCase());
    r.setName(body.name().trim());
    r.setPermissions(new HashSet<>(resolvePermissions(body.permissionCodes())));
    AdminRole saved = roles.save(r);
    audit.record("ROLE_CREATED", "ROLES", String.valueOf(saved.getId()), null,
        "{\"code\":\"" + saved.getCode() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('ROLES_WRITE')")
  public ApiResponse<AdminRole> update(@PathVariable long id, @Valid @RequestBody RoleRequest body, HttpServletRequest req) {
    AdminRole r = find(id);
    roles.findByCode(body.code().trim().toUpperCase()).ifPresent(existing -> {
      if (!existing.getId().equals(id)) {
        throw new IllegalArgumentException("A role with this code already exists");
      }
    });
    r.setCode(body.code().trim().toUpperCase());
    r.setName(body.name().trim());
    r.setPermissions(new HashSet<>(resolvePermissions(body.permissionCodes())));
    AdminRole saved = roles.save(r);
    audit.record("ROLE_UPDATED", "ROLES", String.valueOf(id), null,
        "{\"code\":\"" + saved.getCode() + "\",\"permissions\":" + saved.getPermissions().size() + "}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @PreAuthorize("hasAuthority('ROLES_WRITE')")
  public ApiResponse<Void> delete(@PathVariable long id, HttpServletRequest req) {
    AdminRole r = find(id);
    if (admins.existsByRole(r)) {
      throw new IllegalArgumentException("Role is assigned to administrators and cannot be deleted");
    }
    roles.delete(r);
    audit.record("ROLE_DELETED", "ROLES", String.valueOf(id), null, null, req);
    return ApiResponse.ok("Role deleted");
  }

  @GetMapping("/permissions")
  @PreAuthorize("hasAuthority('ROLES_READ')")
  public ApiResponse<List<AdminPermission>> permissions() {
    return ApiResponse.ok(permissions.findAll());
  }

  private AdminRole find(long id) {
    return roles.findById(id).orElseThrow(() -> NotFoundException.of("Role", id));
  }

  private List<AdminPermission> resolvePermissions(List<String> codes) {
    if (codes == null || codes.isEmpty()) {
      return List.of();
    }
    List<AdminPermission> found = permissions.findByCodeIn(codes.stream().map(String::trim).map(String::toUpperCase).toList());
    if (found.size() != new HashSet<>(codes).size()) {
      throw new IllegalArgumentException("One or more permission codes do not exist");
    }
    return found;
  }

  public record RoleRequest(
      @NotBlank @Size(max = 80) String code,
      @NotBlank @Size(max = 120) String name,
      List<String> permissionCodes) {
  }
}
