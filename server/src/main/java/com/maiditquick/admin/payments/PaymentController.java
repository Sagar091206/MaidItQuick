package com.maiditquick.admin.payments;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.common.PageResponse;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.payment.Payment;
import com.makeitquick.payment.PaymentRepository;
import com.makeitquick.payment.PaymentStatus;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Locale;
import java.util.UUID;

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
        : payments.findByStatus(parseStatus(status), pageable);
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
    Booking booking = resolveBooking(body.bookingId());
    String reference = body.transactionId() == null || body.transactionId().isBlank()
        ? "TXN-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase(Locale.ROOT)
        : body.transactionId().trim();
    Payment p = new Payment(booking, reference,
        body.method() == null ? "CASH" : body.method(), toPaise(body.amount()));
    applyStatus(p, body.status());
    Payment saved = payments.save(p);
    audit.record("PAYMENT_CREATED", "PAYMENTS", String.valueOf(saved.getId()), null,
        "{\"amountPaise\":" + saved.getAmountPaise() + ",\"status\":\"" + saved.getStatus() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public ApiResponse<Payment> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    Payment p = find(id);
    if (body.bookingId() != null) {
      p = new Payment(resolveBooking(body.bookingId()), p.getReference(),
          body.method() == null ? p.getMethod() : body.method(), toPaise(body.amount()));
    }
    if (body.status() != null) {
      applyStatus(p, body.status());
    }
    Payment saved = payments.save(p);
    audit.record("PAYMENT_UPDATED", "PAYMENTS", String.valueOf(id), null,
        "{\"amountPaise\":" + saved.getAmountPaise() + ",\"status\":\"" + saved.getStatus() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public ApiResponse<Payment> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    Payment p = find(id);
    applyStatus(p, input.status());
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

  private void applyStatus(Payment p, String status) {
    PaymentStatus next = parseStatus(status);
    switch (next) {
      case PAID -> p.markPaid(null);
      case FAILED -> p.markFailed(null);
      case REFUNDED -> p.markRefunded(null);
      default -> p.setStatus(PaymentStatus.PENDING);
    }
  }

  private PaymentStatus parseStatus(String status) {
    try {
      return PaymentStatus.valueOf(status.trim().toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException e) {
      throw new IllegalArgumentException("Unknown payment status: " + status);
    }
  }

  private Payment find(long id) {
    return payments.findById(id).orElseThrow(() -> NotFoundException.of("Payment", id));
  }

  private Booking resolveBooking(Long id) {
    if (id == null) {
      throw new IllegalArgumentException("bookingId is required");
    }
    return bookings.findById(id).orElseThrow(() -> NotFoundException.of("Booking", id));
  }

  private int toPaise(BigDecimal rupees) {
    if (rupees == null) {
      return 0;
    }
    return rupees.movePointRight(2).setScale(0, RoundingMode.HALF_UP).intValue();
  }

  public record Upsert(
      Long bookingId,
      @DecimalMin("0.01") BigDecimal amount,
      @Pattern(regexp = "CASH|CARD|ONLINE|UPI|WALLET|BANK_TRANSFER") String method,
      @Pattern(regexp = "PENDING|PAID|REFUNDED|FAILED") String status,
      @Size(max = 128) String transactionId) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "PENDING|PAID|REFUNDED|FAILED") String status) {
  }
}
