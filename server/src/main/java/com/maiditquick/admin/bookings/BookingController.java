package com.maiditquick.admin.bookings;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.common.PageResponse;
import com.maiditquick.admin.notifications.Notification;
import com.maiditquick.admin.notifications.NotificationRepository;
import com.maiditquick.admin.services.ServiceOffering;
import com.maiditquick.admin.services.ServiceOfferingRepository;
import com.maiditquick.admin.settings.SettingRepository;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
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
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@RestController
@RequestMapping("/api/v1/admin/bookings")
public class BookingController {

  private final BookingRepository bookings;
  private final UserRepository users;
  private final ServiceOfferingRepository services;
  private final SettingRepository settings;
  private final NotificationRepository notifications;
  private final AuditService audit;

  public BookingController(BookingRepository bookings, UserRepository users,
                           ServiceOfferingRepository services, SettingRepository settings,
                           NotificationRepository notifications, AuditService audit) {
    this.bookings = bookings;
    this.users = users;
    this.services = services;
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
        : bookings.search(query.trim().toLowerCase(), pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @GetMapping("/live")
  @PreAuthorize("hasAuthority('BOOKINGS_READ')")
  public ApiResponse<List<Booking>> live() {
    return ApiResponse.ok(bookings.findByStatusIn(List.of(
        BookingStatus.SEARCHING, BookingStatus.REQUESTED, BookingStatus.NO_PARTNER_FOUND,
        BookingStatus.ASSIGNED, BookingStatus.ACCEPTED, BookingStatus.ON_THE_WAY,
        BookingStatus.ARRIVED, BookingStatus.IN_PROGRESS)));
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
    List<BookingStatus> statuses = toStatuses(status);
    Specification<Booking> spec = (root, q, cb) -> {
      List<Predicate> ands = new ArrayList<>();
      if (statuses != null) ands.add(root.get("status").in(statuses));
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
        ors.add(cb.like(cb.lower(root.get("worker").get("name")), like));
        ors.add(cb.like(cb.lower(root.get("worker").get("phone")), like));
        Long id = parseId(partnerQ);
        if (id != null) ors.add(cb.equal(root.get("worker").get("id"), id));
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
    UserAccount customer = resolveCustomer(body.customerId());
    String serviceName = resolveServiceName(body.serviceId(), body.service());
    String scheduledFor = body.scheduledAt() == null || body.scheduledAt().isBlank()
        ? java.time.LocalDateTime.now().plusMinutes(60).toString() : body.scheduledAt();
    Booking b = new Booking(customer, serviceName,
        body.address() == null ? "" : body.address(), scheduledFor,
        body.pinCode(), body.durationMinutes(), null, null, 0,
        body.notes() == null ? "" : body.notes());
    b.setPaymentAmountPaise(toPaise(body.totalAmount()));
    if (body.workerId() != null) {
      b.setWorker(resolveWorker(body.workerId()));
    }
    if (body.status() != null) {
      b.setStatus(toStatus(body.status()));
    }
    Booking saved = bookings.save(b);
    audit.record("BOOKING_CREATED", "BOOKINGS", String.valueOf(saved.getId()), null,
        "{\"status\":\"" + saved.getStatus() + "\",\"amountPaise\":" + saved.getPaymentAmountPaise() + "}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('BOOKINGS_WRITE')")
  public ApiResponse<Booking> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    Booking b = find(id);
    if (body.workerId() != null) {
      b.setWorker(resolveWorker(body.workerId()));
    }
    if (body.status() != null) {
      b.setStatus(toStatus(body.status()));
    }
    if (body.scheduledAt() != null && !body.scheduledAt().isBlank()) {
      b.reschedule(body.scheduledAt());
    }
    if (body.totalAmount() != null) {
      b.setPaymentAmountPaise(toPaise(body.totalAmount()));
    }
    Booking saved = bookings.save(b);
    audit.record("BOOKING_UPDATED", "BOOKINGS", String.valueOf(id), null,
        "{\"status\":\"" + saved.getStatus() + "\",\"amountPaise\":" + saved.getPaymentAmountPaise() + "}", req);
    return ApiResponse.ok(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('BOOKINGS_WRITE')")
  public ApiResponse<Booking> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    Booking b = find(id);
    BookingStatus next = toStatus(input.status());
    if (next == BookingStatus.CANCELLED) {
      b.cancel("Cancelled by administrator");
    } else {
      b.setStatus(next);
    }
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
        + (b.getWorker() != null ? " / " + b.getWorker().getName() : "") + " at " + b.getAddress() + ".");
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
    Booking b = find(id);
    if (b.getStatus() == BookingStatus.COMPLETED || b.getStatus() == BookingStatus.CANCELLED) {
      throw new IllegalArgumentException("Completed or cancelled bookings cannot be deleted");
    }
    b.cancel("Deleted by administrator");
    bookings.save(b);
    audit.record("BOOKING_DELETED", "BOOKINGS", String.valueOf(id), null,
        "{\"softDelete\":true,\"cancelled\":true}", req);
  }

  private Booking find(long id) {
    return bookings.findById(id).orElseThrow(() -> NotFoundException.of("Booking", id));
  }

  private UserAccount resolveCustomer(Long id) {
    if (id == null) {
      throw new IllegalArgumentException("customerId is required");
    }
    UserAccount u = users.findById(id)
        .orElseThrow(() -> NotFoundException.of("Customer", id));
    if (u.getRole() != Role.CUSTOMER) {
      throw new IllegalArgumentException("User " + id + " is not a customer");
    }
    return u;
  }

  private UserAccount resolveWorker(Long id) {
    UserAccount u = users.findById(id)
        .orElseThrow(() -> NotFoundException.of("Worker", id));
    if (u.getRole() != Role.WORKER) {
      throw new IllegalArgumentException("User " + id + " is not a worker");
    }
    return u;
  }

  private String resolveServiceName(Long serviceId, String serviceName) {
    if (serviceName != null && !serviceName.isBlank()) {
      return serviceName.trim();
    }
    if (serviceId != null) {
      ServiceOffering s = services.findById(serviceId)
          .orElseThrow(() -> NotFoundException.of("Service", serviceId));
      return s.getName();
    }
    throw new IllegalArgumentException("A service (name or id) is required");
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
    BigDecimal amount = BigDecimal.valueOf(b.getPaymentAmountPaise(), 2);
    BigDecimal commission = amount.multiply(pct).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
    return new BookingLedger(
        b.getId(), b.getStatus().name(), b.getCreatedAt(), b.getScheduledFor(),
        b.getCustomer() != null ? b.getCustomer().getName() : null,
        b.getCustomer() != null ? b.getCustomer().getPhone() : null,
        b.getWorker() != null ? b.getWorker().getName() : null,
        b.getWorker() != null ? b.getWorker().getPhone() : null,
        b.getService(),
        amount, pct, commission, amount.subtract(commission));
  }

  private List<BookingStatus> toStatuses(String status) {
    if (status == null || status.isBlank()) {
      return null;
    }
    String s = status.trim().toUpperCase(Locale.ROOT);
    return switch (s) {
      case "PENDING" -> List.of(BookingStatus.REQUESTED, BookingStatus.SEARCHING, BookingStatus.NO_PARTNER_FOUND);
      case "CONFIRMED" -> List.of(BookingStatus.ASSIGNED, BookingStatus.ACCEPTED, BookingStatus.ON_THE_WAY, BookingStatus.ARRIVED);
      case "IN_PROGRESS" -> List.of(BookingStatus.IN_PROGRESS);
      case "COMPLETED" -> List.of(BookingStatus.COMPLETED);
      case "CANCELLED" -> List.of(BookingStatus.CANCELLED, BookingStatus.EXPIRED);
      default -> {
        try {
          yield List.of(BookingStatus.valueOf(s));
        } catch (IllegalArgumentException e) {
          yield List.of();
        }
      }
    };
  }

  private BookingStatus toStatus(String status) {
    String s = status.trim().toUpperCase(Locale.ROOT);
    return switch (s) {
      case "PENDING" -> BookingStatus.REQUESTED;
      case "CONFIRMED" -> BookingStatus.ASSIGNED;
      case "IN_PROGRESS" -> BookingStatus.IN_PROGRESS;
      case "COMPLETED" -> BookingStatus.COMPLETED;
      case "CANCELLED" -> BookingStatus.CANCELLED;
      default -> BookingStatus.valueOf(s);
    };
  }

  private int toPaise(BigDecimal rupees) {
    if (rupees == null) {
      return 0;
    }
    return rupees.movePointRight(2).setScale(0, RoundingMode.HALF_UP).intValue();
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
      Long id, String status, Instant createdAt, String scheduledAt,
      String customerName, String customerPhone, String workerName, String workerPhone,
      String serviceName, BigDecimal amountPaid, BigDecimal commissionPct,
      BigDecimal commission, BigDecimal netPayout) {
  }

  public record Upsert(
      Long customerId,
      Long serviceId,
      String service,
      Long workerId,
      Long partnerId,
      @Pattern(regexp = "PENDING|CONFIRMED|IN_PROGRESS|COMPLETED|CANCELLED") String status,
      String scheduledAt,
      @Size(max = 500) String address,
      @Size(max = 1000) String notes,
      @DecimalMin("0.0") BigDecimal totalAmount,
      String pinCode,
      @Min(1) Integer durationMinutes) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "PENDING|CONFIRMED|IN_PROGRESS|COMPLETED|CANCELLED") String status) {
  }
}
