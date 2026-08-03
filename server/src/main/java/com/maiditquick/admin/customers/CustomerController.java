package com.maiditquick.admin.customers;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.common.PageResponse;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/customers")
public class CustomerController {

  private final UserRepository customers;
  private final BookingRepository bookings;
  private final AuditService audit;
  private final PasswordEncoder passwords;

  public CustomerController(UserRepository customers, BookingRepository bookings,
                            AuditService audit, PasswordEncoder passwords) {
    this.customers = customers;
    this.bookings = bookings;
    this.audit = audit;
    this.passwords = passwords;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('CUSTOMERS_READ')")
  public ApiResponse<PageResponse<UserView>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "") String deleted,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    Page<UserAccount> result = query.isBlank()
        ? customers.findByRole(Role.CUSTOMER, pageable)
        : customers.searchByRole(Role.CUSTOMER, query.trim().toLowerCase(), pageable);
    return ApiResponse.ok(PageResponse.from(result, this::toView));
  }

  @GetMapping("/overview")
  @PreAuthorize("hasAuthority('CUSTOMERS_READ')")
  public ApiResponse<PageResponse<CustomerOverview>> overview(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "") String deleted,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    Page<UserAccount> result = query.isBlank()
        ? customers.findByRole(Role.CUSTOMER, pageable)
        : customers.searchByRole(Role.CUSTOMER, query.trim().toLowerCase(), pageable);
    return ApiResponse.ok(PageResponse.from(result, this::toOverview));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('CUSTOMERS_READ')")
  public ApiResponse<UserView> get(@PathVariable long id) {
    return ApiResponse.ok(toView(find(id)));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public ApiResponse<UserView> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    if (customers.existsByEmailIgnoreCase(body.email().trim())) {
      throw new IllegalArgumentException("A customer with this email already exists");
    }
    UserAccount c = new UserAccount(body.name().trim(), body.email().trim(),
        passwords.encode(UUID.randomUUID().toString()),
        body.phone() == null || body.phone().isBlank() ? "UNSET-" + UUID.randomUUID() : body.phone().trim(),
        Role.CUSTOMER);
    c.setEnabled(!isSuspended(body.status()));
    UserAccount saved = customers.save(c);
    audit.record("CUSTOMER_CREATED", "CUSTOMERS", String.valueOf(saved.getId()), null,
        "{\"name\":\"" + saved.getName() + "\",\"email\":\"" + saved.getEmail() + "\"}", req);
    return ApiResponse.created(toView(saved));
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public ApiResponse<UserView> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    UserAccount c = find(id);
    if (customers.existsByEmailIgnoreCaseAndIdNot(body.email().trim(), id)) {
      throw new IllegalArgumentException("A customer with this email already exists");
    }
    c.setName(body.name().trim());
    c.setEmail(body.email().trim());
    if (body.status() != null) {
      c.setEnabled(!isSuspended(body.status()));
    }
    UserAccount saved = customers.save(c);
    audit.record("CUSTOMER_UPDATED", "CUSTOMERS", String.valueOf(id), null,
        "{\"name\":\"" + saved.getName() + "\",\"email\":\"" + saved.getEmail() + "\"}", req);
    return ApiResponse.ok(toView(saved));
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public ApiResponse<UserView> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    UserAccount c = find(id);
    c.setEnabled(!isSuspended(input.status()));
    UserAccount saved = customers.save(c);
    audit.record("CUSTOMER_STATUS_CHANGED", "CUSTOMERS", String.valueOf(id), null,
        "{\"status\":\"" + input.status() + "\"}", req);
    return ApiResponse.ok(toView(saved));
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    UserAccount c = find(id);
    if (!c.isEnabled()) {
      throw new IllegalArgumentException("Customer is already disabled");
    }
    c.disable();
    customers.save(c);
    audit.record("CUSTOMER_DELETED", "CUSTOMERS", String.valueOf(id), null,
        "{\"softDelete\":true,\"name\":\"" + c.getName() + "\"}", req);
  }

  @PostMapping("/{id}/restore")
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public ApiResponse<UserView> restore(@PathVariable long id, HttpServletRequest req) {
    UserAccount c = find(id);
    if (c.isEnabled()) {
      throw new IllegalArgumentException("Customer is not disabled");
    }
    c.setEnabled(true);
    UserAccount saved = customers.save(c);
    audit.record("CUSTOMER_RESTORED", "CUSTOMERS", String.valueOf(id), null,
        "{\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.ok(toView(saved));
  }

  private UserAccount find(long id) {
    return customers.findById(id).orElseThrow(() -> NotFoundException.of("Customer", id));
  }

  private boolean isSuspended(String status) {
    return "SUSPENDED".equalsIgnoreCase(status);
  }

  private UserView toView(UserAccount c) {
    return new UserView(c.getId(), c.getName(), c.getEmail(), c.getPhone(),
        c.isEnabled() ? "ACTIVE" : "SUSPENDED", c.getCreatedAt());
  }

  private CustomerOverview toOverview(UserAccount c) {
    return new CustomerOverview(
        c.getId(), c.getName(), c.getEmail(), c.getPhone(), "",
        c.isEnabled() ? "ACTIVE" : "SUSPENDED", BigDecimal.ZERO, null,
        bookings.countByCustomerId(c.getId()), c.getCreatedAt());
  }

  public record UserView(
      Long id, String name, String email, String phone, String status, Instant createdAt) {
  }

  public record Upsert(
      @NotBlank @Size(max = 160) String name,
      @NotBlank @Email @Size(max = 255) String email,
      @Size(max = 40) String phone,
      @Size(max = 500) String address,
      @Pattern(regexp = "ACTIVE|SUSPENDED") String status) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "ACTIVE|SUSPENDED") String status) {
  }

  public record CustomerOverview(
      Long id, String name, String email, String phone, String address,
      String status, BigDecimal walletBalance, Instant deletedAt,
      long bookingCount, Instant createdAt) {
  }
}
