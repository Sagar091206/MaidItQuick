package com.maiditquick.admin.users;

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
import org.springframework.web.bind.annotation.*;

import java.time.Instant;

@RestController
@RequestMapping("/api/v1/admin/users")
public class UserController {

  private static final java.util.regex.Pattern EMAIL_MATCHER =
      java.util.regex.Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");

  private final UserRepository users;
  private final AuditService audit;

  public UserController(UserRepository users, AuditService audit) {
    this.users = users;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('USERS_READ')")
  public ApiResponse<PageResponse<User>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    var result = query.isBlank()
        ? users.findAll(pageable)
        : users.findByEmailIgnoreCaseContainingOrNameIgnoreCaseContaining(query.toLowerCase(), query.toLowerCase(), pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('USERS_READ')")
  public ApiResponse<User> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('USERS_WRITE')")
  public ApiResponse<User> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    if (!EMAIL_MATCHER.matcher(body.email()).matches()) {
      throw new IllegalArgumentException("Invalid email address");
    }
    if (users.existsByEmailIgnoreCase(body.email())) {
      throw new IllegalArgumentException("A user with this email already exists");
    }
    User u = new User();
    u.setName(body.name().trim());
    u.setEmail(body.email().trim());
    u.setPhone(body.phone() == null ? null : body.phone().trim());
    u.setStatus(body.status() == null ? "ACTIVE" : body.status());
    User saved = users.save(u);
    audit.record("USER_CREATED", "USERS", String.valueOf(saved.getId()), null,
        "{\"name\":\"" + saved.getName() + "\",\"email\":\"" + saved.getEmail() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('USERS_WRITE')")
  public ApiResponse<User> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    User u = find(id);
    if (!EMAIL_MATCHER.matcher(body.email()).matches()) {
      throw new IllegalArgumentException("Invalid email address");
    }
    if (users.existsByEmailIgnoreCaseAndIdNot(body.email(), id)) {
      throw new IllegalArgumentException("A user with this email already exists");
    }
    String before = "{\"name\":\"" + u.getName() + "\",\"email\":\"" + u.getEmail() + "\"}";
    u.setName(body.name().trim());
    u.setEmail(body.email().trim());
    u.setPhone(body.phone() == null ? null : body.phone().trim());
    if (body.status() != null) {
      u.setStatus(body.status());
    }
    u.setUpdatedAt(Instant.now());
    User saved = users.save(u);
    audit.record("USER_UPDATED", "USERS", String.valueOf(id), before,
        "{\"name\":\"" + saved.getName() + "\",\"email\":\"" + saved.getEmail() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('USERS_WRITE')")
  public ApiResponse<User> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    User u = find(id);
    u.setStatus(input.status());
    u.setUpdatedAt(Instant.now());
    User saved = users.save(u);
    audit.record("USER_STATUS_CHANGED", "USERS", String.valueOf(id), null,
        "{\"status\":\"" + input.status() + "\",\"reason\":\"" + input.reason().replace("\"", "\\\"") + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('USERS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    User u = find(id);
    users.delete(u);
    audit.record("USER_DELETED", "USERS", String.valueOf(id), null, null, req);
  }

  private User find(long id) {
    return users.findById(id).orElseThrow(() -> NotFoundException.of("User", id));
  }

  public record Upsert(
      @NotBlank @Size(max = 160) String name,
      @NotBlank @Email @Size(max = 255) String email,
      @Size(max = 40) String phone,
      @Pattern(regexp = "ACTIVE|SUSPENDED|VERIFIED") String status) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "ACTIVE|SUSPENDED|VERIFIED") String status,
      @NotBlank @Size(max = 500) String reason) {
  }
}
