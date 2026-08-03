package com.makeitquick.admin.users;

import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.common.NotFoundException;
import com.makeitquick.admin.common.PageResponse;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/users")
public class UserController {

  private static final java.util.regex.Pattern EMAIL_MATCHER =
      java.util.regex.Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");

  private final UserRepository users;
  private final AuditService audit;
  private final PasswordEncoder passwords;

  public UserController(UserRepository users, AuditService audit, PasswordEncoder passwords) {
    this.users = users;
    this.audit = audit;
    this.passwords = passwords;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('USERS_READ')")
  public ApiResponse<PageResponse<UserView>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    var result = query.isBlank()
        ? users.findAll(pageable)
        : users.search(query.trim().toLowerCase(), pageable);
    return ApiResponse.ok(PageResponse.from(result, this::toView));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('USERS_READ')")
  public ApiResponse<UserView> get(@PathVariable long id) {
    return ApiResponse.ok(toView(find(id)));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('USERS_WRITE')")
  public ApiResponse<UserView> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    if (!EMAIL_MATCHER.matcher(body.email()).matches()) {
      throw new IllegalArgumentException("Invalid email address");
    }
    if (users.existsByEmailIgnoreCase(body.email().trim())) {
      throw new IllegalArgumentException("A user with this email already exists");
    }
    UserAccount u = new UserAccount(body.name().trim(), body.email().trim(),
        passwords.encode(UUID.randomUUID().toString()),
        body.phone() == null || body.phone().isBlank() ? "UNSET-" + UUID.randomUUID() : body.phone().trim(),
        body.role() == null ? Role.CUSTOMER : body.role());
    u.setEnabled(!isSuspended(body.status()));
    UserAccount saved = users.save(u);
    audit.record("USER_CREATED", "USERS", String.valueOf(saved.getId()), null,
        "{\"name\":\"" + saved.getName() + "\",\"email\":\"" + saved.getEmail() + "\"}", req);
    return ApiResponse.created(toView(saved));
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('USERS_WRITE')")
  public ApiResponse<UserView> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    UserAccount u = find(id);
    if (!EMAIL_MATCHER.matcher(body.email()).matches()) {
      throw new IllegalArgumentException("Invalid email address");
    }
    if (users.existsByEmailIgnoreCaseAndIdNot(body.email().trim(), id)) {
      throw new IllegalArgumentException("A user with this email already exists");
    }
    String before = "{\"name\":\"" + u.getName() + "\",\"email\":\"" + u.getEmail() + "\"}";
    u.setName(body.name().trim());
    u.setEmail(body.email().trim());
    if (body.status() != null) {
      u.setEnabled(!isSuspended(body.status()));
    }
    UserAccount saved = users.save(u);
    audit.record("USER_UPDATED", "USERS", String.valueOf(id), before,
        "{\"name\":\"" + saved.getName() + "\",\"email\":\"" + saved.getEmail() + "\"}", req);
    return ApiResponse.ok(toView(saved));
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('USERS_WRITE')")
  public ApiResponse<UserView> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    UserAccount u = find(id);
    u.setEnabled(!isSuspended(input.status()));
    UserAccount saved = users.save(u);
    audit.record("USER_STATUS_CHANGED", "USERS", String.valueOf(id), null,
        "{\"status\":\"" + input.status() + "\",\"reason\":\"" + input.reason().replace("\"", "\\\"") + "\"}", req);
    return ApiResponse.ok(toView(saved));
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('USERS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    UserAccount u = find(id);
    if (!u.isEnabled()) {
      throw new IllegalArgumentException("User is already suspended");
    }
    u.setEnabled(false);
    users.save(u);
    audit.record("USER_DELETED", "USERS", String.valueOf(id), null,
        "{\"softDelete\":true,\"name\":\"" + u.getName() + "\"}", req);
  }

  private UserAccount find(long id) {
    return users.findById(id).orElseThrow(() -> NotFoundException.of("User", id));
  }

  private boolean isSuspended(String status) {
    return "SUSPENDED".equalsIgnoreCase(status);
  }

  private UserView toView(UserAccount u) {
    return new UserView(u.getId(), u.getName(), u.getEmail(), u.getPhone(),
        u.getRole().name(), u.isEnabled() ? "ACTIVE" : "SUSPENDED", u.getCreatedAt());
  }

  public record Upsert(
      @NotBlank @Size(max = 160) String name,
      @NotBlank @Email @Size(max = 255) String email,
      @Size(max = 40) String phone,
      Role role,
      @Pattern(regexp = "ACTIVE|SUSPENDED|VERIFIED") String status) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "ACTIVE|SUSPENDED|VERIFIED") String status,
      @NotBlank @Size(max = 500) String reason) {
  }

  public record UserView(
      Long id, String name, String email, String phone, String role,
      String status, Instant createdAt) {
  }
}
