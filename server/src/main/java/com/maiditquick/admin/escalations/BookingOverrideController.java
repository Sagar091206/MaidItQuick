package com.maiditquick.admin.escalations;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.common.PageResponse;
import com.maiditquick.admin.notifications.Notification;
import com.maiditquick.admin.notifications.NotificationRepository;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.payment.Payment;
import com.makeitquick.payment.PaymentRepository;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.makeitquick.worker.WorkerProfile;
import com.makeitquick.worker.WorkerProfileRepository;
import jakarta.persistence.criteria.Predicate;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/overrides")
public class BookingOverrideController {

  private final BookingRepository bookings;
  private final UserRepository workers;
  private final WorkerProfileRepository workerProfiles;
  private final PaymentRepository payments;
  private final DisputeRepository disputes;
  private final NotificationRepository notifications;
  private final AuditService audit;
  private final Path uploadDir;

  public BookingOverrideController(BookingRepository bookings, UserRepository workers,
                                   WorkerProfileRepository workerProfiles,
                                   PaymentRepository payments,
                                   DisputeRepository disputes, NotificationRepository notifications,
                                   AuditService audit,
                                   @Value("${app.uploads-dir:uploads}") String uploadsDir) {
    this.bookings = bookings;
    this.workers = workers;
    this.workerProfiles = workerProfiles;
    this.payments = payments;
    this.disputes = disputes;
    this.notifications = notifications;
    this.audit = audit;
    this.uploadDir = Paths.get(uploadsDir).toAbsolutePath().normalize();
  }

  /* ---------- Active booking intervention ---------- */

  @PostMapping("/bookings/{id}/cancel")
  @PreAuthorize("hasAuthority('OVERRIDES_WRITE')")
  public ApiResponse<Booking> cancel(@PathVariable long id,
                                     @Valid @RequestBody CancelInput input,
                                     HttpServletRequest req) {
    Booking b = findBooking(id);
    if (b.getStatus() == BookingStatus.COMPLETED) {
      throw new IllegalArgumentException("Completed bookings cannot be cancelled");
    }
    String before = b.getStatus().name();
    b.cancel(input.reason() == null || input.reason().isBlank() ? "Cancelled by administrator" : input.reason());
    Booking saved = bookings.save(b);
    audit.record("BOOKING_CANCELLED_MANUAL", "ESCALATIONS", String.valueOf(id),
        "{\"status\":\"" + before + "\"}",
        "{\"status\":\"CANCELLED\",\"reason\":\"" + (input.reason() == null ? "" : input.reason()) + "\"}",
        req);
    notify("Booking cancelled — #" + id,
        "Booking #" + id + " was manually cancelled by an administrator"
            + (input.reason() == null || input.reason().isBlank() ? "." : " — " + input.reason()),
        "WARNING");
    return ApiResponse.ok("Booking cancelled", saved);
  }

  @PostMapping("/bookings/{id}/reassign")
  @PreAuthorize("hasAuthority('OVERRIDES_WRITE')")
  public ApiResponse<Booking> reassign(@PathVariable long id,
                                       @Valid @RequestBody ReassignInput input,
                                       HttpServletRequest req) {
    Booking b = findBooking(id);
    Long workerId = input.newWorkerId() != null ? input.newWorkerId() : input.newPartnerId();
    UserAccount worker = resolveWorker(workerId);
    String before = b.getWorker() == null ? null : b.getWorker().getName();
    b.assign(worker);
    Booking saved = bookings.save(b);
    audit.record("BOOKING_REASSIGNED", "ESCALATIONS", String.valueOf(id),
        "{\"worker\":\"" + (before == null ? "" : before) + "\"}",
        "{\"worker\":\"" + worker.getName() + "\",\"newWorkerId\":" + worker.getId() + "}",
        req);
    notify("Booking reassigned — #" + id,
        "Booking #" + id + " was reassigned to " + worker.getName()
            + (input.reason() == null || input.reason().isBlank() ? "." : " — " + input.reason()),
        "INFO");
    return ApiResponse.ok("Booking reassigned", saved);
  }

  @PostMapping("/bookings/{id}/refund")
  @PreAuthorize("hasAuthority('OVERRIDES_WRITE')")
  public ApiResponse<Payment> refund(@PathVariable long id,
                                     @Valid @RequestBody RefundInput input,
                                     HttpServletRequest req) {
    Booking b = findBooking(id);
    int totalPaise = b.getPaymentAmountPaise();
    int refundPaise = toPaise(input.amount());
    if (refundPaise > totalPaise) {
      throw new IllegalArgumentException("Refund cannot exceed the booking amount "
          + BigDecimal.valueOf(totalPaise, 2).toPlainString());
    }
    Payment payment = new Payment(b,
        "REF-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase(Locale.ROOT),
        "ONLINE", refundPaise);
    payment.markRefunded("Admin override");
    Payment saved = payments.save(payment);
    audit.record("BOOKING_REFUNDED", "ESCALATIONS", String.valueOf(id),
        "{\"amount\":\"" + input.amount().toPlainString() + "\"}",
        "{\"paymentId\":" + saved.getId() + ",\"reference\":\"" + saved.getReference()
            + "\",\"reason\":\"" + (input.reason() == null ? "" : input.reason()) + "\"}",
        req);
    notify("Refund issued — booking #" + id,
        "₹" + input.amount().toPlainString() + " refunded against the booking"
            + (input.reason() == null || input.reason().isBlank() ? "." : " — " + input.reason()),
        "SUCCESS");
    return ApiResponse.ok("Refund issued", saved);
  }

  @GetMapping("/workers/nearby")
  @PreAuthorize("hasAuthority('OVERRIDES_WRITE')")
  public ApiResponse<List<NearbyWorker>> nearby(
      @RequestParam double lat,
      @RequestParam double lng,
      @RequestParam(defaultValue = "0") long excludeId,
      @RequestParam(defaultValue = "5") int limit) {
    int max = Math.min(Math.max(limit, 1), 20);
    return ApiResponse.ok(workerProfiles.findAll().stream()
        .filter(WorkerProfile::isReadyForJobs)
        .filter(w -> w.getLastLatitude() != null && w.getLastLongitude() != null)
        .filter(w -> !w.getUser().getId().equals(excludeId))
        .map(w -> new NearbyWorker(w.getUser().getId(), w.getUser().getName(), w.getUser().getPhone(),
            haversineKm(lat, lng, w.getLastLatitude(), w.getLastLongitude())))
        .sorted(Comparator.comparingDouble(NearbyWorker::distanceKm))
        .limit(max)
        .toList());
  }

  /* ---------- Support disputes ---------- */

  @GetMapping("/disputes")
  @PreAuthorize("hasAuthority('DISPUTES_READ')")
  public ApiResponse<PageResponse<Dispute>> disputes(
      @RequestParam(defaultValue = "") String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    PageRequest pageable = PageRequest.of(page, Math.min(Math.max(size, 1), 100),
        Sort.by(Sort.Direction.DESC, "id"));
    Specification<Dispute> spec = (root, q, cb) -> {
      List<Predicate> ands = new ArrayList<>();
      if (!status.isBlank()) ands.add(cb.equal(root.get("status"), status.trim().toUpperCase(Locale.ROOT)));
      return cb.and(ands.toArray(new Predicate[0]));
    };
    Page<Dispute> result = disputes.findAll(spec, pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @PostMapping("/disputes")
  @PreAuthorize("hasAuthority('DISPUTES_WRITE')")
  public ApiResponse<Dispute> createDispute(@Valid @RequestBody DisputeInput input,
                                            HttpServletRequest req) {
    Dispute d = new Dispute();
    if (input.bookingId() != null) {
      d.setBooking(findBooking(input.bookingId()));
    }
    d.setReporterType(input.reporterType() == null ? "CUSTOMER" : input.reporterType().toUpperCase(Locale.ROOT));
    d.setSubject(input.subject().trim());
    d.setDescription(input.description());
    Dispute saved = disputes.save(d);
    audit.record("DISPUTE_CREATED", "ESCALATIONS", String.valueOf(saved.getId()), null,
        "{\"subject\":\"" + saved.getSubject() + "\",\"reporter\":\"" + saved.getReporterType() + "\"}",
        req);
    return ApiResponse.ok("Dispute recorded", saved);
  }

  @PostMapping("/disputes/{id}/logs")
  @PreAuthorize("hasAuthority('DISPUTES_WRITE')")
  public ApiResponse<Dispute> uploadLog(@PathVariable long id,
                                        @RequestParam("log") MultipartFile log,
                                        HttpServletRequest req) {
    Dispute d = findDispute(id);
    deleteFile(d.getLogPath());
    d.setLogPath(saveLog(log, id));
    Dispute saved = disputes.save(d);
    audit.record("DISPUTE_LOG_UPLOADED", "ESCALATIONS", String.valueOf(id), null,
        "{\"logPath\":\"" + saved.getLogPath() + "\"}", req);
    return ApiResponse.ok("Log uploaded", saved);
  }

  @PostMapping("/disputes/{id}/resolve")
  @PreAuthorize("hasAuthority('DISPUTES_WRITE')")
  public ApiResponse<Dispute> resolve(@PathVariable long id,
                                      @Valid @RequestBody ResolveInput input,
                                      HttpServletRequest req) {
    Dispute d = findDispute(id);
    if ("RESOLVED".equals(d.getStatus())) {
      throw new IllegalArgumentException("This dispute is already resolved");
    }
    d.setStatus("RESOLVED");
    d.setResolution(input.resolution().trim());
    d.setResolvedAt(Instant.now());
    d.setResolvedByAdminId(currentAdminId());
    Dispute saved = disputes.save(d);
    audit.record("DISPUTE_RESOLVED", "ESCALATIONS", String.valueOf(id), "{\"status\":\"OPEN\"}",
        "{\"resolution\":\"" + saved.getResolution() + "\",\"resolvedBy\":" + saved.getResolvedByAdminId() + "}",
        req);
    notify("Dispute resolved — #" + id,
        "Support dispute \"" + saved.getSubject() + "\" was resolved: " + saved.getResolution(),
        "SUCCESS");
    return ApiResponse.ok("Dispute resolved", saved);
  }

  /* ---------- helpers ---------- */

  private Booking findBooking(long id) {
    return bookings.findById(id).orElseThrow(() -> NotFoundException.of("Booking", id));
  }

  private Dispute findDispute(long id) {
    return disputes.findById(id).orElseThrow(() -> NotFoundException.of("Dispute", id));
  }

  private UserAccount resolveWorker(Long id) {
    if (id == null) {
      throw new IllegalArgumentException("A worker id is required");
    }
    UserAccount worker = workers.findById(id)
        .orElseThrow(() -> NotFoundException.of("Worker", id));
    if (worker.getRole() != Role.WORKER) {
      throw new IllegalArgumentException("User " + id + " is not a worker");
    }
    WorkerProfile profile = workerProfiles.findByUser(worker)
        .orElseThrow(() -> new IllegalArgumentException("Worker has no onboarding profile"));
    if (!profile.isReadyForJobs()) {
      throw new IllegalArgumentException("Only workers with approved KYC can be assigned to a booking");
    }
    return worker;
  }

  private int toPaise(BigDecimal rupees) {
    return rupees.movePointRight(2).setScale(0, RoundingMode.HALF_UP).intValue();
  }

  private double haversineKm(double lat1, double lng1, Double lat2, Double lng2) {
    if (lat2 == null || lng2 == null) return Double.MAX_VALUE;
    double r = 6371.0;
    double dLat = Math.toRadians(lat2 - lat1);
    double dLng = Math.toRadians(lng2 - lng1);
    double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
        + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
        * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return 2 * r * Math.asin(Math.sqrt(a));
  }

  private String saveLog(MultipartFile file, long disputeId) {
    try {
      String original = file.getOriginalFilename() == null ? "log.txt" : file.getOriginalFilename();
      String ext = original.contains(".")
          ? original.substring(original.lastIndexOf('.')).toLowerCase()
          : ".txt";
      if (ext.length() > 10) ext = ".txt";
      Files.createDirectories(uploadDir.resolve("disputes"));
      String name = disputeId + "-" + System.currentTimeMillis() + ext;
      Path target = uploadDir.resolve("disputes").resolve(name);
      file.transferTo(target);
      return "/uploads/disputes/" + name;
    } catch (IOException e) {
      throw new IllegalArgumentException("Could not store dispute log: " + e.getMessage());
    }
  }

  private void deleteFile(String urlPath) {
    if (urlPath == null || urlPath.isBlank()) return;
    try {
      Files.deleteIfExists(uploadDir
          .resolve(Paths.get(urlPath.replace("/uploads/", "")).getFileName().toString()));
    } catch (IOException ignored) {
    }
  }

  private long currentAdminId() {
    try {
      return Long.parseLong(SecurityContextHolder.getContext().getAuthentication().getName());
    } catch (Exception e) {
      return -1;
    }
  }

  private void notify(String title, String message, String type) {
    Notification n = new Notification();
    n.setTitle(title);
    n.setMessage(message);
    n.setType(type);
    notifications.save(n);
  }

  public record CancelInput(@Size(max = 500) String reason) {}

  public record ReassignInput(Long newWorkerId, Long newPartnerId, @Size(max = 500) String reason) {}

  public record RefundInput(@NotNull @DecimalMin("0.01") BigDecimal amount,
                            @Size(max = 500) String reason) {}

  public record DisputeInput(Long bookingId,
                             @NotBlank @Size(max = 20) String reporterType,
                             @NotBlank @Size(max = 160) String subject,
                             @Size(max = 2000) String description) {}

  public record ResolveInput(@NotBlank @Size(max = 2000) String resolution) {}

  public record NearbyWorker(Long id, String name, String phone, double distanceKm) {}
}
