package com.maiditquick.admin.customers;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.bookings.BookingRepository;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.common.PageResponse;
import jakarta.persistence.criteria.Predicate;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/customers")
public class CustomerController {

  private final CustomerRepository customers;
  private final BookingRepository bookings;
  private final AuditService audit;

  public CustomerController(CustomerRepository customers, BookingRepository bookings,
                            AuditService audit) {
    this.customers = customers;
    this.bookings = bookings;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('CUSTOMERS_READ')")
  public ApiResponse<PageResponse<Customer>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "") String deleted,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    Page<Customer> result = customers.findAll(searchSpec(query, deleted), pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @GetMapping("/overview")
  @PreAuthorize("hasAuthority('CUSTOMERS_READ')")
  public ApiResponse<PageResponse<CustomerOverview>> overview(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "") String deleted,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    Page<Customer> result = customers.findAll(searchSpec(query, deleted), pageable);
    return ApiResponse.ok(PageResponse.from(result,
        c -> new CustomerOverview(c.getId(), c.getName(), c.getEmail(), c.getPhone(),
            c.getAddress(), c.getStatus(), c.getWalletBalance(), c.getDeletedAt(),
            bookings.countByCustomerId(c.getId()), c.getCreatedAt())));
  }

  private Specification<Customer> searchSpec(String query, String deleted) {
    return (root, q, cb) -> {
      List<Predicate> ands = new ArrayList<>();
      boolean showDeleted = "true".equalsIgnoreCase(deleted);
      ands.add(showDeleted ? cb.isNotNull(root.get("deletedAt")) : cb.isNull(root.get("deletedAt")));
      if (!query.isBlank()) {
        String like = "%" + query.trim().toLowerCase() + "%";
        ands.add(cb.or(
            cb.like(cb.lower(root.get("name")), like),
            cb.like(cb.lower(root.get("email")), like),
            cb.like(cb.lower(root.get("phone")), like)));
      }
      return cb.and(ands.toArray(new Predicate[0]));
    };
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('CUSTOMERS_READ')")
  public ApiResponse<Customer> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public ApiResponse<Customer> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    if (customers.existsByEmailIgnoreCase(body.email().trim())) {
      throw new IllegalArgumentException("A customer with this email already exists");
    }
    Customer c = new Customer();
    c.setName(body.name().trim());
    c.setEmail(body.email().trim());
    c.setPhone(body.phone());
    c.setAddress(body.address());
    c.setStatus(body.status() == null ? "ACTIVE" : body.status());
    Customer saved = customers.save(c);
    audit.record("CUSTOMER_CREATED", "CUSTOMERS", String.valueOf(saved.getId()), null,
        "{\"name\":\"" + saved.getName() + "\",\"email\":\"" + saved.getEmail() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public ApiResponse<Customer> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    Customer c = find(id);
    if (customers.existsByEmailIgnoreCaseAndIdNot(body.email().trim(), id)) {
      throw new IllegalArgumentException("A customer with this email already exists");
    }
    c.setName(body.name().trim());
    c.setEmail(body.email().trim());
    c.setPhone(body.phone());
    c.setAddress(body.address());
    if (body.status() != null) {
      c.setStatus(body.status());
    }
    c.setUpdatedAt(Instant.now());
    Customer saved = customers.save(c);
    audit.record("CUSTOMER_UPDATED", "CUSTOMERS", String.valueOf(id), null,
        "{\"name\":\"" + saved.getName() + "\",\"email\":\"" + saved.getEmail() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public ApiResponse<Customer> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    Customer c = find(id);
    c.setStatus(input.status());
    c.setUpdatedAt(Instant.now());
    Customer saved = customers.save(c);
    audit.record("CUSTOMER_STATUS_CHANGED", "CUSTOMERS", String.valueOf(id), null,
        "{\"status\":\"" + input.status() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    Customer c = find(id);
    if (c.getDeletedAt() != null) {
      throw new IllegalArgumentException("Customer is already deleted");
    }
    c.setDeletedAt(Instant.now());
    c.setUpdatedAt(Instant.now());
    customers.save(c);
    audit.record("CUSTOMER_DELETED", "CUSTOMERS", String.valueOf(id), null,
        "{\"softDelete\":true,\"name\":\"" + c.getName() + "\"}", req);
  }

  @PostMapping("/{id}/restore")
  @PreAuthorize("hasAuthority('CUSTOMERS_WRITE')")
  public ApiResponse<Customer> restore(@PathVariable long id, HttpServletRequest req) {
    Customer c = find(id);
    if (c.getDeletedAt() == null) {
      throw new IllegalArgumentException("Customer is not deleted");
    }
    c.setDeletedAt(null);
    c.setUpdatedAt(Instant.now());
    Customer saved = customers.save(c);
    audit.record("CUSTOMER_RESTORED", "CUSTOMERS", String.valueOf(id), null,
        "{\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  private Customer find(long id) {
    return customers.findById(id).orElseThrow(() -> NotFoundException.of("Customer", id));
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
