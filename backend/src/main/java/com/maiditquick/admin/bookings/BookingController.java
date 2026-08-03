package com.maiditquick.admin.bookings;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.common.PageResponse;
import com.maiditquick.admin.customers.Customer;
import com.maiditquick.admin.customers.CustomerRepository;
import com.maiditquick.admin.notifications.Notification;
import com.maiditquick.admin.notifications.NotificationRepository;
import com.maiditquick.admin.partners.Partner;
import com.maiditquick.admin.partners.PartnerRepository;
import com.maiditquick.admin.services.ServiceOffering;
import com.maiditquick.admin.services.ServiceOfferingRepository;
import com.maiditquick.admin.settings.SettingRepository;
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
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/bookings")
public class BookingController {

  private final BookingRepository bookings;
  private final CustomerRepository customers;
  private final ServiceOfferingRepository services;
  private final PartnerRepository partners;
  private final SettingRepository settings;
  private final NotificationRepository notifications;
  private final AuditService audit;

  public BookingController(BookingRepository bookings, CustomerRepository customers,
                           ServiceOfferingRepository services, PartnerRepository partners,
                           SettingRepository settings, NotificationRepository notifications,
                           AuditService audit) {
    this.bookings = bookings;
    this.customers = customers;
    this.services = services;
    this.partners = partners;
    this.settings = settings;
    this.notifications = notifications;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('BOOKINGS_READ')")
  public ApiResponse<PageResponse<Booking>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    var result = query.isBlank()
        ? bookings.findAll(pageable)
        : bookings.search(query.toLowerCase(), pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @GetMapping("/live")
  @PreAuthorize("hasAuthority('BOOKINGS_READ')")
  public ApiResponse<List<Booking>> live() {
    return ApiResponse.ok(bookings.findByStatusIn(List.of("PENDING", "CONFIRMED", "IN_PROGRESS")));
  }

  @GetMapping("/ledger")
  @PreAuthorize("hasAuthority('BOOKINGS_READ')")
  public ApiResponse<PageResponse<BookingLedger>> ledger(
      @RequestParam(defaultValue = "") String status,
      @RequestParam(defaultValue = "") String from,
      @RequestParam(defaultValue = "") String to,
      @RequestParam(defaultValue = "") String customerQ,
      @RequestParam(defaultValue = "") String partnerQ,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
    Specification<Booking> spec = (root, q, cb) -> {
      List<Predicate> ands = new ArrayList<>();
      if (!status.isBlank()) ands.add(cb.equal(root.get("status"), status));
      if (!from.isBlank()) {
        LocalDate d = LocalDate.parse(from);
        ands.add(cb.greaterThanOrEqualTo(root.get("createdAt"), d.atStartOfDay(ZoneOffset.UTC).toInstant()));
      }
      if (!to.isBlank()) {
        LocalDate d = LocalDate.parse(to);
        ands.add(cb.lessThan(root.get("createdAt"), d.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant()));
      }
      if (!customerQ.isBlank()) {
        String like = "%" + customerQ.trim().toLowerCase() + "%";
        List<Predicate> ors = new ArrayList<>();
        ors.add(cb.like(cb.lower(root.get("customer").get("name")), like));
        ors.add(cb.like(cb.lower(root.get("customer").get("phone")), like));
        Long id = parseId(customerQ);
        if (id != null) ors.add(cb.equal(root.get("customer").get("id"), id));
        ands.add(cb.or(ors.toArray(new Predicate[0])));
      }
      if (!partnerQ.isBlank()) {
        String like = "%" + partnerQ.trim().toLowerCase() + "%";
        List<Predicate> ors = new ArrayList<>();
        ors.add(cb.like(cb.lower(root.get("partner").get("name")), like));
        ors.add(cb.like(cb.lower(root.get("partner").get("phone")), like));
        Long id = parseId(partnerQ);
        if (id != null) ors.add(cb.equal(root.get("partner").get("id"), id));
        ands.add(cb.or(ors.toArray(new Predicate[0])));
      }
      return cb.and(ands.toArray(new Predicate[0]));
    };
    Page<Booking> result = bookings.findAll(spec, pageable);
    BigDecimal pct = commissionPct();
    return ApiResponse.ok(PageResponse.from(result, b -> toLedger(b, pct)));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('BOOKINGS_READ')")
  public ApiResponse<Booking> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('BOOKINGS_WRITE')")
  public ApiResponse<Booking> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    Booking b = new Booking();
    apply(b, body);
    Booking saved = bookings.save(b);
    audit.record("BOOKING_CREATED", "BOOKINGS", String.valueOf(saved.getId()), null,
        "{\"status\":\"" + saved.getStatus() + "\",\"total\":" + saved.getTotalAmount() + "}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('BOOKINGS_WRITE')")
  public ApiResponse<Booking> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    Booking b = find(id);
    apply(b, body);
    b.setUpdatedAt(Instant.now());
    Booking saved = bookings.save(b);
    audit.record("BOOKING_UPDATED", "BOOKINGS", String.valueOf(id), null,
        "{\"status\":\"" + saved.getStatus() + "\",\"total\":" + saved.getTotalAmount() + "}", req);
    return ApiResponse.ok(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('BOOKINGS_WRITE')")
  public ApiResponse<Booking> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    Booking b = find(id);
    Instant now = Instant.now();
    b.setStatus(input.status());
    if ("IN_PROGRESS".equals(input.status()) && b.getStartedAt() == null) b.setStartedAt(now);
    if ("COMPLETED".equals(input.status())) b.setCompletedAt(now);
    if ("PENDING".equals(input.status()) || "CONFIRMED".equals(input.status())) b.setCompletedAt(null);
    b.setUpdatedAt(now);
    Booking saved = bookings.save(b);
    audit.record("BOOKING_STATUS_CHANGED", "BOOKINGS", String.valueOf(id), null,
        "{\"status\":\"" + input.status() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @PostMapping("/{id}/escalate")
  @PreAuthorize("hasAuthority('BOOKINGS_WRITE')")
  public ApiResponse<Booking> escalate(@PathVariable long id, HttpServletRequest req) {
    Booking b = find(id);
    Notification n = new Notification();
    n.setTitle("Emergency support requested — Booking #" + b.getId());
    n.setMessage("Operator escalation for " + (b.getCustomer() != null ? b.getCustomer().getName() : "unknown customer")
        + (b.getPartner() != null ? " / " + b.getPartner().getName() : "") + " at " + b.getAddress() + ".");
    n.setType("ERROR");
    notifications.save(n);
    audit.record("BOOKING_ESCALATED", "BOOKINGS", String.valueOf(id), null,
        "{\"bookingId\":" + id + ",\"escalatedAt\":\"" + Instant.now() + "\"}", req);
    return ApiResponse.ok("Emergency support has been dispatched for this booking", b);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('BOOKINGS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    bookings.delete(find(id));
    audit.record("BOOKING_DELETED", "BOOKINGS", String.valueOf(id), null, null, req);
  }

  private void apply(Booking b, Upsert body) {
    b.setCustomer(resolveCustomer(body.customerId()));
    b.setService(resolveService(body.serviceId()));
    b.setPartner(resolvePartner(body.partnerId()));
    b.setStatus(body.status() == null ? "PENDING" : body.status());
    b.setScheduledAt(body.scheduledAt());
    b.setAddress(body.address());
    b.setNotes(body.notes());
    b.setTotalAmount(body.totalAmount());
    b.setLatitude(body.latitude());
    b.setLongitude(body.longitude());
  }

  private Booking find(long id) {
    return bookings.findById(id).orElseThrow(() -> NotFoundException.of("Booking", id));
  }

  private Customer resolveCustomer(Long id) {
    if (id == null) {
      return null;
    }
    return customers.findById(id).orElseThrow(() -> NotFoundException.of("Customer", id));
  }

  private ServiceOffering resolveService(Long id) {
    if (id == null) {
      return null;
    }
    return services.findById(id).orElseThrow(() -> NotFoundException.of("Service", id));
  }

  private Partner resolvePartner(Long id) {
    if (id == null) {
      return null;
    }
    return partners.findById(id).orElseThrow(() -> NotFoundException.of("Partner", id));
  }

  private BigDecimal commissionPct() {
    return settings.findBySettingKey("platform_commission_pct")
        .map(s -> {
          try {
            return new BigDecimal(s.getSettingValue());
          } catch (NumberFormatException e) {
            return BigDecimal.valueOf(18);
          }
        })
        .orElse(BigDecimal.valueOf(18));
  }

  private BookingLedger toLedger(Booking b, BigDecimal pct) {
    BigDecimal amount = b.getTotalAmount() == null ? BigDecimal.ZERO : b.getTotalAmount();
    BigDecimal commission = amount.multiply(pct).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
    return new BookingLedger(
        b.getId(), b.getStatus(), b.getCreatedAt(), b.getScheduledAt(),
        b.getCustomer() != null ? b.getCustomer().getName() : null,
        b.getCustomer() != null ? b.getCustomer().getPhone() : null,
        b.getPartner() != null ? b.getPartner().getName() : null,
        b.getPartner() != null ? b.getPartner().getPhone() : null,
        b.getService() != null ? b.getService().getName() : null,
        amount, pct, commission, amount.subtract(commission));
  }

  private Long parseId(String raw) {
    try {
      long v = Long.parseLong(raw.trim());
      return v > 0 ? v : null;
    } catch (NumberFormatException e) {
      return null;
    }
  }

  public record BookingLedger(
      Long id, String status, Instant createdAt, LocalDateTime scheduledAt,
      String customerName, String customerPhone, String partnerName, String partnerPhone,
      String serviceName, BigDecimal amountPaid, BigDecimal commissionPct,
      BigDecimal commission, BigDecimal netPayout) {
  }

  public record Upsert(
      Long customerId,
      Long serviceId,
      Long partnerId,
      @Pattern(regexp = "PENDING|CONFIRMED|IN_PROGRESS|COMPLETED|CANCELLED") String status,
      LocalDateTime scheduledAt,
      @Size(max = 500) String address,
      @Size(max = 1000) String notes,
      @NotNull @DecimalMin("0.0") BigDecimal totalAmount,
      @DecimalMin("-90") @DecimalMax("90") Double latitude,
      @DecimalMin("-180") @DecimalMax("180") Double longitude) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "PENDING|CONFIRMED|IN_PROGRESS|COMPLETED|CANCELLED") String status) {
  }
}
