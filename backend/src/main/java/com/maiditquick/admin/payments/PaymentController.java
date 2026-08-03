package com.maiditquick.admin.payments;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.bookings.Booking;
import com.maiditquick.admin.bookings.BookingRepository;
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

import java.math.BigDecimal;
import java.time.Instant;

@RestController
@RequestMapping("/api/v1/admin/payments")
public class PaymentController {

  private final PaymentRepository payments;
  private final BookingRepository bookings;
  private final AuditService audit;

  public PaymentController(PaymentRepository payments, BookingRepository bookings, AuditService audit) {
    this.payments = payments;
    this.bookings = bookings;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('PAYMENTS_READ')")
  public ApiResponse<PageResponse<Payment>> list(
      @RequestParam(defaultValue = "") String status,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    var result = status.isBlank()
        ? payments.findAll(pageable)
        : payments.findByStatusContainingIgnoreCase(status, pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('PAYMENTS_READ')")
  public ApiResponse<Payment> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public ApiResponse<Payment> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    Payment p = new Payment();
    apply(p, body);
    if ("PAID".equals(p.getStatus())) {
      p.setPaidAt(Instant.now());
    }
    Payment saved = payments.save(p);
    audit.record("PAYMENT_CREATED", "PAYMENTS", String.valueOf(saved.getId()), null,
        "{\"amount\":" + saved.getAmount() + ",\"status\":\"" + saved.getStatus() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public ApiResponse<Payment> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    Payment p = find(id);
    apply(p, body);
    if ("PAID".equals(p.getStatus()) && p.getPaidAt() == null) {
      p.setPaidAt(Instant.now());
    }
    Payment saved = payments.save(p);
    audit.record("PAYMENT_UPDATED", "PAYMENTS", String.valueOf(id), null,
        "{\"amount\":" + saved.getAmount() + ",\"status\":\"" + saved.getStatus() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public ApiResponse<Payment> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    Payment p = find(id);
    p.setStatus(input.status());
    if ("PAID".equals(input.status()) && p.getPaidAt() == null) {
      p.setPaidAt(Instant.now());
    }
    Payment saved = payments.save(p);
    audit.record("PAYMENT_STATUS_CHANGED", "PAYMENTS", String.valueOf(id), null,
        "{\"status\":\"" + input.status() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    payments.delete(find(id));
    audit.record("PAYMENT_DELETED", "PAYMENTS", String.valueOf(id), null, null, req);
  }

  private void apply(Payment p, Upsert body) {
    p.setBooking(resolveBooking(body.bookingId()));
    p.setAmount(body.amount());
    p.setMethod(body.method() == null ? "CASH" : body.method());
    p.setStatus(body.status() == null ? "PENDING" : body.status());
    p.setTransactionId(body.transactionId());
  }

  private Payment find(long id) {
    return payments.findById(id).orElseThrow(() -> NotFoundException.of("Payment", id));
  }

  private Booking resolveBooking(Long id) {
    if (id == null) {
      return null;
    }
    return bookings.findById(id).orElseThrow(() -> NotFoundException.of("Booking", id));
  }

  public record Upsert(
      Long bookingId,
      @NotNull @DecimalMin("0.01") BigDecimal amount,
      @Pattern(regexp = "CASH|CARD|ONLINE|BANK_TRANSFER") String method,
      @Pattern(regexp = "PENDING|PAID|REFUNDED|FAILED") String status,
      @Size(max = 128) String transactionId) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "PENDING|PAID|REFUNDED|FAILED") String status) {
  }
}
