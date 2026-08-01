package com.makeitquick.booking;
import com.makeitquick.catalog.ServiceCatalogService;
import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.operations.RefundRequest;
import com.makeitquick.operations.RefundService;
import com.makeitquick.operations.ServiceAreaService;
import com.makeitquick.security.*;
import com.makeitquick.worker.WorkerSafetyService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.SecureRandom;
import java.util.*;
import org.springframework.http.*;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/bookings")
@CrossOrigin(origins = "*")
public class BookingController {
    private final BookingRepository repo;
    private final BookingServiceRepository bookingServices;
    private final BookingEventRepository bookingEvents;
    private final SessionResolver resolver;
    private final UserRepository users;
    private final NotificationService notifications;
    private final WorkerSafetyService workerSafety;
    private final RefundService refunds;
    private final ServiceAreaService serviceAreas;
    private final ServiceCatalogService catalog;
    private final BookingAssignmentService assigner;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);
    private final SecureRandom random = new SecureRandom();

    BookingController(BookingRepository r, BookingServiceRepository bs, BookingEventRepository events,
                      SessionResolver resolver, UserRepository users, NotificationService n, WorkerSafetyService w,
                      RefundService refunds, ServiceAreaService areas, ServiceCatalogService catalog,
                      BookingAssignmentService assigner) {
        repo = r;
        bookingServices = bs;
        bookingEvents = events;
        this.resolver = resolver;
        this.users = users;
        notifications = n;
        workerSafety = w;
        this.refunds = refunds;
        serviceAreas = areas;
        this.catalog = catalog;
        this.assigner = assigner;
    }

    private UserAccount me(String h) {
        return resolver.fromBearer(h)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Valid session required"));
    }

    private void role(UserAccount u, Role... roles) {
        for (Role r : roles) if (u.getRole() == r) return;
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Role not permitted");
    }

    @PostMapping
    public Map<String, Object> create(@RequestHeader("Authorization") String h, @Valid @RequestBody Create x) {
        UserAccount u = me(h);
        role(u, Role.CUSTOMER);
        if (!u.profileComplete()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Complete your profile before booking a service");
        }
        requireValidScheduledFor(x.scheduledFor());
        List<String> requested = serviceNames(x);
        for (String service : requested) {
            if (!catalog.isEnabled(service)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, service + " is currently unavailable");
            }
        }
        if (!serviceAreas.acceptsBookings(x.pinCode())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "MaidItQuick is not available at this PIN code yet");
        }
        if (x.durationMinutes() != null && (x.durationMinutes() < 30 || x.durationMinutes() > 480)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Duration must be between 30 and 480 minutes");
        }
        int discount = promoDiscount(x.promoCode());
        String serviceLabel = String.join(", ", requested);
        Booking b = repo.save(new Booking(u, serviceLabel, x.address(), x.scheduledFor(), x.pinCode(),
                x.durationMinutes(), x.optionLabel(), x.promoCode(), discount, x.specialInstructions()));
        bookingServices.saveAll(requested.stream().map(service -> new BookingService(b, service)).toList());
        recordEvent(b, BookingStatus.REQUESTED, "Booking requested by " + u.getName());
        notifications.send(u, NotificationType.BOOKING, "Booking requested",
                "Your " + b.getService() + " booking has been requested for " + b.getScheduledFor() + ".");
        assignBestWorker(b, requested);
        return view(b);
    }

    private void assignBestWorker(Booking b, List<String> services) {
        if (b.getStatus() != BookingStatus.REQUESTED) return;
        Optional<UserAccount> best = assigner.findBestWorker(services, b.getPinCode());
        if (best.isEmpty()) return;
        UserAccount worker = best.get();
        b.assign(worker);
        repo.save(b);
        recordEvent(b, BookingStatus.ASSIGNED, "Assigned to " + worker.getName());
        notifications.send(worker, NotificationType.WORKER_ASSIGNMENT, "New job assigned",
                "You have been assigned " + b.getService() + " for " + b.getScheduledFor() + ".");
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Worker assigned",
                "A worker has been assigned to your " + b.getService() + " booking.");
    }

    @GetMapping
    public List<Map<String, Object>> list(@RequestHeader("Authorization") String h) {
        UserAccount u = me(h);
        List<Booking> x = u.getRole() == Role.ADMIN ? repo.findAll()
                : u.getRole() == Role.WORKER ? repo.findByWorkerIdOrderByIdDesc(u.getId())
                : repo.findByCustomerIdOrderByIdDesc(u.getId());
        return x.stream().map(this::view).toList();
    }

    @GetMapping("/{id}")
    public Map<String, Object> detail(@RequestHeader("Authorization") String h, @PathVariable Long id) {
        UserAccount u = me(h);
        Booking b = get(id);
        if (u.getRole() != Role.ADMIN && b.getWorker() != null && !b.getWorker().getId().equals(u.getId())
                && !b.getCustomer().getId().equals(u.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not permitted");
        }
        if (u.getRole() == Role.WORKER && (b.getWorker() == null || !b.getWorker().getId().equals(u.getId()))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not permitted");
        }
        return view(b);
    }

    @PostMapping("/{id}/assign")
    public Map<String, Object> assign(@RequestHeader("Authorization") String h, @PathVariable Long id, @RequestBody Assign x) {
        role(me(h), Role.ADMIN);
        Booking b = get(id);
        UserAccount w = users.findById(x.workerId())
                .filter(u -> u.getRole() == Role.WORKER)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Worker not found"));
        if (!workerSafety.eligibleForDispatch(w)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Worker must have approved KYC and be available");
        }
        b.assign(w);
        b = repo.save(b);
        recordEvent(b, BookingStatus.ASSIGNED, "Assigned to " + w.getName());
        notifications.send(w, NotificationType.WORKER_ASSIGNMENT, "New job assigned",
                "You have been assigned " + b.getService() + " for " + b.getScheduledFor() + ".");
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Worker assigned",
                "A worker has been assigned to your " + b.getService() + " booking.");
        return view(b);
    }

    @PostMapping("/{id}/accept")
    public Map<String, Object> accept(@RequestHeader("Authorization") String h, @PathVariable Long id) {
        UserAccount u = me(h);
        Booking b = get(id);
        if (b.getWorker() == null || !b.getWorker().getId().equals(u.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Assigned worker required");
        }
        if (b.getStatus() != BookingStatus.ASSIGNED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only assigned bookings can be accepted");
        }
        b.accept();
        b = repo.save(b);
        recordEvent(b, BookingStatus.ACCEPTED, "Worker " + u.getName() + " accepted the job");
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Worker accepted",
                "Your worker " + u.getName() + " has accepted your " + b.getService() + " booking.");
        return view(b);
    }

    @PostMapping("/{id}/reject")
    public Map<String, Object> reject(@RequestHeader("Authorization") String h, @PathVariable Long id) {
        UserAccount u = me(h);
        Booking b = get(id);
        if (b.getWorker() == null || !b.getWorker().getId().equals(u.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Assigned worker required");
        }
        if (b.getStatus() != BookingStatus.ASSIGNED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only assigned bookings can be declined");
        }
        b.unassign();
        b = repo.save(b);
        recordEvent(b, BookingStatus.REQUESTED, "Worker " + u.getName() + " declined the job");
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Worker declined",
                "Your assigned worker declined the job. We are finding another worker.");
        assignBestWorker(b, serviceNamesOf(b));
        return view(b);
    }

    @PostMapping("/{id}/cancel")
    public Map<String, Object> cancel(@RequestHeader("Authorization") String h, @PathVariable Long id, @RequestBody Reason x) {
        UserAccount u = me(h);
        Booking b = get(id);
        boolean admin = u.getRole() == Role.ADMIN;
        if (!b.getCustomer().getId().equals(u.getId()) && !admin) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your booking");
        }
        if (b.getStatus() == BookingStatus.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Booking is already cancelled");
        }
        if (b.getStatus() == BookingStatus.IN_PROGRESS || b.getStatus() == BookingStatus.COMPLETED
                || b.getStatus() == BookingStatus.ON_THE_WAY) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Booking cannot be cancelled after the worker is on the way");
        }
        if (!admin && b.getStatus() != BookingStatus.REQUESTED
                && b.getStatus() != BookingStatus.ASSIGNED
                && b.getStatus() != BookingStatus.ACCEPTED) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Only requested, assigned or accepted bookings can be cancelled");
        }
        b.cancel(x.reason());
        b = repo.save(b);
        recordEvent(b, BookingStatus.CANCELLED, "Cancelled by " + u.getName() + ": " + x.reason());
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Booking cancelled",
                "Your " + b.getService() + " booking was cancelled.");
        if (b.getWorker() != null) {
            notifications.send(b.getWorker(), NotificationType.BOOKING, "Booking cancelled",
                    "The assigned " + b.getService() + " booking was cancelled.");
        }
        return view(b);
    }

    @PostMapping("/{id}/reschedule")
    public Map<String, Object> reschedule(@RequestHeader("Authorization") String h, @PathVariable Long id, @RequestBody Slot x) {
        UserAccount u = me(h);
        Booking b = get(id);
        if (!b.getCustomer().getId().equals(u.getId()) || b.getStatus() != BookingStatus.REQUESTED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only unassigned customer bookings can be rescheduled");
        }
        requireValidScheduledFor(x.scheduledFor());
        b.reschedule(x.scheduledFor());
        b = repo.save(b);
        recordEvent(b, b.getStatus(), "Rescheduled to " + b.getScheduledFor());
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Booking rescheduled",
                "Your booking is now scheduled for " + b.getScheduledFor() + ".");
        return view(b);
    }

    @PostMapping("/{id}/refund-request")
    public Map<String, Object> requestRefund(@RequestHeader("Authorization") String h, @PathVariable Long id,
                                             @Valid @RequestBody RefundInput x) {
        UserAccount u = me(h);
        Booking b = get(id);
        if (!b.getCustomer().getId().equals(u.getId()) || b.getStatus() != BookingStatus.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only your cancelled bookings can be submitted for refund review");
        }
        RefundRequest refund = refunds.request("MIQ-" + b.getId(), x.reason(), x.amountPaise());
        notifications.send(u, NotificationType.BOOKING, "Refund request submitted",
                "Your refund request is awaiting admin review.");
        return Map.of("id", refund.getId(), "bookingReference", refund.getBookingReference(),
                "status", refund.getStatus(), "message", "Refund request submitted for review");
    }

    @PostMapping("/{id}/on-the-way")
    public Map<String, Object> onTheWay(@RequestHeader("Authorization") String h, @PathVariable Long id) {
        Booking b = get(id);
        if (b.getWorker() == null || !b.getWorker().getId().equals(me(h).getId())
                || (b.getStatus() != BookingStatus.ASSIGNED && b.getStatus() != BookingStatus.ACCEPTED)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only an assigned worker can start travelling");
        }
        b.enRoute();
        b = repo.save(b);
        recordEvent(b, BookingStatus.ON_THE_WAY, "Worker is on the way");
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Worker is on the way",
                "Your worker is travelling to your service location.");
        return view(b);
    }

    @PostMapping("/{id}/arrived")
    public Map<String, Object> arrived(@RequestHeader("Authorization") String h, @PathVariable Long id) {
        UserAccount u = me(h);
        Booking b = get(id);
        if (b.getWorker() == null || !b.getWorker().getId().equals(u.getId())
                || b.getStatus() != BookingStatus.ON_THE_WAY) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only a travelling worker can mark arrival");
        }
        b.arrive();
        b = repo.save(b);
        recordEvent(b, BookingStatus.ARRIVED, "Worker arrived at the location");
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Worker arrived",
                "Your worker " + u.getName() + " has arrived at the service location.");
        return view(b);
    }

    @PostMapping("/{id}/start-code")
    public Map<String, String> startCode(@RequestHeader("Authorization") String h, @PathVariable Long id) {
        Booking b = get(id);
        if (b.getWorker() == null || !b.getWorker().getId().equals(me(h).getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Assigned worker required");
        }
        if (b.getStatus() != BookingStatus.ON_THE_WAY && b.getStatus() != BookingStatus.ARRIVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Start OTP can only be issued after the worker is on the way");
        }
        String code = String.format("%06d", random.nextInt(1_000_000));
        b.setStartOtpHash(encoder.encode(code));
        repo.save(b);
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Start-service OTP",
                "Share this OTP with your worker only after they arrive: " + code);
        return Map.of("message", "A start OTP was sent to the customer.");
    }

    @PostMapping("/{id}/start")
    public Map<String, Object> start(@RequestHeader("Authorization") String h, @PathVariable Long id, @RequestBody Otp x) {
        Booking b = get(id);
        if (b.getWorker() == null || !b.getWorker().getId().equals(me(h).getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Assigned worker required");
        }
        if (b.getStatus() != BookingStatus.ON_THE_WAY && b.getStatus() != BookingStatus.ARRIVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Worker must be on the way before starting the service");
        }
        if (!encoder.matches(x.code(), b.getStartOtpHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid start OTP");
        }
        b.begin();
        b = repo.save(b);
        recordEvent(b, BookingStatus.IN_PROGRESS, "Service started");
        return view(b);
    }

    @PostMapping("/{id}/end-code")
    public Map<String, String> endCode(@RequestHeader("Authorization") String h, @PathVariable Long id) {
        Booking b = get(id);
        if (b.getWorker() == null || !b.getWorker().getId().equals(me(h).getId())
                || b.getStatus() != BookingStatus.IN_PROGRESS) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Job is not in progress");
        }
        String code = String.format("%06d", random.nextInt(1_000_000));
        b.setEndOtpHash(encoder.encode(code));
        repo.save(b);
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Complete-service OTP",
                "Share this OTP with your worker only after the service is complete: " + code);
        return Map.of("message", "A completion OTP was sent to the customer.");
    }

    @PostMapping("/{id}/complete")
    public Map<String, Object> complete(@RequestHeader("Authorization") String h, @PathVariable Long id, @RequestBody Otp x) {
        Booking b = get(id);
        if (b.getWorker() == null || !b.getWorker().getId().equals(me(h).getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Assigned worker required");
        }
        if (b.getStatus() != BookingStatus.IN_PROGRESS) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Job is not in progress");
        }
        if (!encoder.matches(x.code(), b.getEndOtpHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid end OTP");
        }
        b.complete();
        b = repo.save(b);
        recordEvent(b, BookingStatus.COMPLETED, "Service completed");
        return view(b);
    }

    @PostMapping("/{id}/rating")
    public Map<String, Object> rating(@RequestHeader("Authorization") String h, @PathVariable Long id,
                                      @Valid @RequestBody Rating x) {
        Booking b = get(id);
        if (!b.getCustomer().getId().equals(me(h).getId()) || b.getStatus() != BookingStatus.COMPLETED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only completed customer bookings can be rated");
        }
        b.rate(x.stars(), x.comment());
        return view(repo.save(b));
    }

    @GetMapping("/{id}/invoice")
    public Map<String, Object> invoice(@RequestHeader("Authorization") String h, @PathVariable Long id) {
        Booking b = get(id);
        UserAccount u = me(h);
        if (u.getRole() != Role.ADMIN && !b.getCustomer().getId().equals(u.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not permitted");
        }
        return Map.of("invoice", "MIQ-INV-" + b.getId(), "booking", view(b),
                "paymentStatus", "PAYMENT_GATEWAY_NOT_ENABLED");
    }

    private void requireValidScheduledFor(String scheduledFor) {
        if (scheduledFor == null || scheduledFor.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Scheduled time is required");
        }
        try {
            java.time.LocalDateTime scheduled = java.time.LocalDateTime.parse(scheduledFor);
            if (scheduled.isBefore(java.time.LocalDateTime.now())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Scheduled time must be in the future");
            }
        } catch (java.time.format.DateTimeParseException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid scheduled time format");
        }
    }

    private void recordEvent(Booking b, BookingStatus status, String note) {
        bookingEvents.save(new BookingEvent(b, status, note));
    }

    private List<String> serviceNamesOf(Booking b) {
        return bookingServices.findByBookingIdOrderByIdAsc(b.getId()).stream()
                .map(BookingService::getServiceName)
                .toList();
    }

    private Booking get(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found"));
    }

    private int promoDiscount(String code) {
        if (code == null || code.isBlank()) return 0;
        return switch (code.toUpperCase()) {
            case "WELCOME50" -> 5000;
            case "MAKEITQUICK100" -> 10000;
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Promo code is invalid");
        };
    }

    private List<String> serviceNames(Create x) {
        List<String> names = x.services() == null ? List.of()
                : x.services().stream().filter(Objects::nonNull).map(String::trim)
                        .filter(s -> !s.isBlank()).distinct().toList();
        if (!names.isEmpty()) return names;
        if (x.service() != null && !x.service().isBlank()) return List.of(x.service().trim());
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose at least one service");
    }

    private Map<String, Object> view(Booking b) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", b.getId());
        result.put("service", b.getService());
        result.put("services", bookingServices.findByBookingIdOrderByIdAsc(b.getId()).stream()
                .map(BookingService::getServiceName).toList());
        result.put("address", b.getAddress());
        result.put("pinCode", b.getPinCode());
        result.put("scheduledFor", b.getScheduledFor());
        result.put("durationMinutes", b.getDurationMinutes());
        result.put("optionLabel", b.getOptionLabel());
        result.put("promoCode", b.getPromoCode() == null ? "" : b.getPromoCode());
        result.put("discountPaise", b.getDiscountPaise());
        result.put("specialInstructions", b.getSpecialInstructions());
        result.put("status", b.getStatus());
        result.put("customer", b.getCustomer().getName());
        result.put("worker", b.getWorker() == null ? "Unassigned" : b.getWorker().getName());
        result.put("rating", b.getRating() == null ? 0 : b.getRating());
        result.put("cancellationReason", b.getCancellationReason());
        result.put("events", bookingEvents.findByBookingIdOrderByCreatedAtAsc(b.getId()).stream()
                .map(event -> Map.<String, Object>of(
                        "status", event.getStatus(),
                        "note", event.getNote(),
                        "createdAt", event.getCreatedAt()))
                .toList());
        return result;
    }

    record Create(String service, List<String> services, @NotBlank String address,
                  @NotBlank @Pattern(regexp = "\\d{6}") String pinCode, @NotBlank String scheduledFor,
                  Integer durationMinutes, String optionLabel, String promoCode, String specialInstructions) {}
    record Assign(@NotNull Long workerId) {}
    record Reason(@NotBlank String reason) {}
    record Slot(@NotBlank String scheduledFor) {}
    record RefundInput(@NotBlank String reason, @Min(1) @Max(1000000) int amountPaise) {}
    record Otp(@Pattern(regexp = "\\d{6}") String code) {}
    record Rating(@Min(1) @Max(5) int stars, String comment) {}
}
