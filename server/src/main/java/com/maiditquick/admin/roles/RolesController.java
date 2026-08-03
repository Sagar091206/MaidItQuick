package com.maiditquick.admin.roles;

import com.makeitquick.security.AdminPermissions;
import com.maiditquick.admin.common.ApiResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Read-only role catalog. The unified identity model has a single administrator
 * role ({@code ADMIN}) that carries every permission; the role editor and
 * permission matrix are therefore fixed by the platform.
 */
@RestController
@RequestMapping("/api/v1/admin/roles")
public class RolesController {

  private static final AtomicLong ROLE_SEQ = new AtomicLong(1);
  private static final AtomicLong PERM_SEQ = new AtomicLong(1);

  private static final List<PermissionInfo> PERMISSIONS = AdminPermissions.ALL.stream()
      .map(code -> new PermissionInfo(PERM_SEQ.getAndIncrement(), code, code.replace('_', ' ')))
      .toList();

  private static final List<RoleInfo> ROLES = List.of(
      new RoleInfo(ROLE_SEQ.getAndIncrement(), "ADMIN", "Administrator", PERMISSIONS));

  @GetMapping
  @PreAuthorize("hasAuthority('ROLES_READ')")
  public ApiResponse<List<RoleInfo>> list() {
    return ApiResponse.ok(ROLES);
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('ROLES_READ')")
  public ApiResponse<RoleInfo> get(@PathVariable long id) {
    return ApiResponse.ok(ROLES.get(0));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('ROLES_WRITE')")
  public ApiResponse<Void> create() {
    throw new IllegalArgumentException("Roles are managed by the platform");
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('ROLES_WRITE')")
  public ApiResponse<Void> update() {
    throw new IllegalArgumentException("Roles are managed by the platform");
  }

  @DeleteMapping("/{id}")
  @PreAuthorize("hasAuthority('ROLES_WRITE')")
  public ApiResponse<Void> delete() {
    throw new IllegalArgumentException("Roles are managed by the platform");
  }

  @GetMapping("/permissions")
  @PreAuthorize("hasAuthority('ROLES_READ')")
  public ApiResponse<List<PermissionInfo>> permissions() {
    return ApiResponse.ok(PERMISSIONS);
  }

  public record RoleInfo(Long id, String code, String name, List<PermissionInfo> permissions) {
  }

  public record PermissionInfo(Long id, String code, String description) {
  }
}
