package com.maiditquick.admin.returns;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.bookings.Booking;
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
@RequestMapping("/api/v1/admin/returns")
public class ReturnController {

  private final ReturnRepository returns;
  private final BookingRepository bookings;
  private final AuditService audit;

  public ReturnController(ReturnRepository returns, BookingRepository bookings, AuditService audit) {
    this.returns = returns;
    this.bookings = bookings;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('PAYMENTS_READ')")
  public ApiResponse<PageResponse<ReturnView>> list(
      @RequestParam(defaultValue = "") String status,
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    Specification<ReturnRequest> spec = (root, q, cb) -> {
      List<Predicate> ands = new ArrayList<>();
      if (!status.isBlank()) ands.add(cb.equal(root.get("status"), status));
      if (!query.isBlank()) {
        String like = "%" + query.trim().toLowerCase() + "%";
        ands.add(cb.like(cb.lower(root.get("reason")), like));
        try {
          ands.add(cb.equal(root.get("bookingId"), Long.parseLong(query.trim())));
        } catch (NumberFormatException ignored) {
          ands.add(cb.equal(root.get("id"), -1L));
        }
      }
      return cb.and(ands.toArray(new Predicate[0]));
    };
    Page<ReturnRequest> result = returns.findAll(spec, pageable);
    return ApiResponse.ok(PageResponse.from(result, this::toView));
  }

  private ReturnView toView(ReturnRequest r) {
    Booking b = r.getBookingId() == null ? null : bookings.findById(r.getBookingId()).orElse(null);
    return new ReturnView(r.getId(), r.getBookingId(),
        b == null || b.getCustomer() == null ? "—" : b.getCustomer().getName(),
        b == null || b.getService() == null ? "—" : b.getService().getName(),
        r.getRequestedAmount(), r.getReason(), r.getStatus(), r.getAdminNote(),
        r.getCreatedAt(), r.getDecidedAt());
  }

  @GetMapping("/pending-count")
  @PreAuthorize("hasAuthority('PAYMENTS_READ')")
  public ApiResponse<Long> pendingCount() {
    return ApiResponse.ok(returns.countByStatus("REQUESTED"));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('PAYMENTS_READ')")
  public ApiResponse<ReturnView> get(@PathVariable long id) {
    return ApiResponse.ok(toView(find(id)));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public ApiResponse<ReturnRequest> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    bookings.findById(body.bookingId())
        .orElseThrow(() -> new IllegalArgumentException("Booking not found: " + body.bookingId()));
    ReturnRequest r = new ReturnRequest();
    r.setBookingId(body.bookingId());
    r.setRequestedAmount(body.requestedAmount());
    r.setReason(body.reason().trim());
    ReturnRequest saved = returns.save(r);
    audit.record("RETURN_CREATED", "RETURNS", String.valueOf(saved.getId()), null,
        "{\"bookingId\":" + saved.getBookingId() + ",\"amount\":" + saved.getRequestedAmount() + "}", req);
    return ApiResponse.created(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public ApiResponse<ReturnRequest> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    ReturnRequest r = find(id);
    List<String> allowed = switch (r.getStatus()) {
      case "REQUESTED" -> List.of("APPROVED", "REJECTED");
      case "APPROVED" -> List.of("REFUNDED", "REJECTED");
      default -> List.of();
    };
    if (!allowed.contains(input.status())) {
      throw new IllegalArgumentException(
          "A " + r.getStatus() + " return can only transition to " + allowed + ", not " + input.status());
    }
    r.setStatus(input.status());
    r.setAdminNote(input.note());
    r.setDecidedAt(Instant.now());
    r.setUpdatedAt(Instant.now());
    ReturnRequest saved = returns.save(r);
    audit.record("RETURN_STATUS_CHANGED", "RETURNS", String.valueOf(id), null,
        "{\"status\":\"" + saved.getStatus() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('PAYMENTS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    returns.delete(find(id));
    audit.record("RETURN_DELETED", "RETURNS", String.valueOf(id), null, null, req);
  }

  private ReturnRequest find(long id) {
    return returns.findById(id).orElseThrow(() -> NotFoundException.of("ReturnRequest", id));
  }

  public record Upsert(
      @NotNull Long bookingId,
      @NotNull @DecimalMin("0.01") BigDecimal requestedAmount,
      @NotBlank @Size(max = 1000) String reason) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "APPROVED|REJECTED|REFUNDED") String status,
      @Size(max = 1000) String note) {
  }

  public record ReturnView(
      Long id, Long bookingId, String customerName, String serviceName,
      BigDecimal requestedAmount, String reason, String status, String adminNote,
      Instant createdAt, Instant decidedAt) {
  }
}
