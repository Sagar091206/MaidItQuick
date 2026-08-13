package com.makeitquick.booking;

import com.makeitquick.customer.SavedAddress;
import com.makeitquick.customer.SavedAddressRepository;
import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.payment.PaymentStatus;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import com.makeitquick.worker.WorkerSafetyService;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/instant-bookings")
@CrossOrigin(origins = "*")
public class InstantBookingController {
    private static final int HOURLY_RATE_PAISE = 29900;
    private static final int EXPIRY_MINUTES = 5;
    private final BookingRepository bookings;
    private final SavedAddressRepository addresses;
    private final SessionResolver sessions;
    private final WorkerSafetyService workerSafety;
    private final NotificationService notifications;
    private final InstantRejectionRepository rejections;

    InstantBookingController(BookingRepository bookings, SavedAddressRepository addresses,
                             SessionResolver sessions, WorkerSafetyService workerSafety,
                             NotificationService notifications, InstantRejectionRepository rejections) {
        this.bookings = bookings; this.addresses = addresses; this.sessions = sessions;
        this.workerSafety = workerSafety; this.notifications = notifications; this.rejections = rejections;
    }

    @PostMapping
    public Map<String,Object> create(@RequestHeader("Authorization") String header, @Valid @RequestBody Request input) {
        UserAccount customer = customer(header);
        SavedAddress address = addresses.findByIdAndCustomer(input.addressId(), customer)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service address not found"));
        int price = HOURLY_RATE_PAISE * input.durationMinutes() / 60;
        Booking booking = new Booking(customer, "Basic Home Cleaning", address.getAddress(),
                Instant.now().toString(), address.getPinCode(), input.durationMinutes(), "Instant Maid", "", 0,
                input.instructions() == null ? "" : input.instructions().trim());
        booking.setPaymentAmountPaise(price);
        booking.makeInstant(Instant.now().plus(EXPIRY_MINUTES, ChronoUnit.MINUTES));
        booking = bookings.save(booking);
        notifications.send(customer, NotificationType.BOOKING, "Instant maid request created",
                "Complete payment and we will find an available maid near you.");
        return view(booking);
    }

    @GetMapping("/requests")
    public List<Map<String,Object>> requests(@RequestHeader("Authorization") String header) {
        UserAccount worker = worker(header);
        if (!workerSafety.eligibleForDispatch(worker)) return List.of();
        var rejected = rejections.findByWorkerId(worker.getId()).stream()
                .map(InstantRejection::getBookingId).collect(java.util.stream.Collectors.toSet());
        return bookings.findByStatusOrderByIdDesc(BookingStatus.SEARCHING).stream()
                .filter(this::live).filter(b -> b.getPaymentStatus() == PaymentStatus.PAID)
                .filter(b -> !rejected.contains(b.getId())).map(this::view).toList();
    }

    @PostMapping("/{id}/accept")
    @Transactional
    public Map<String,Object> accept(@RequestHeader("Authorization") String header, @PathVariable Long id) {
        UserAccount worker = worker(header);
        if (!workerSafety.eligibleForDispatch(worker)) throw new ResponseStatusException(HttpStatus.CONFLICT, "You are not eligible to receive bookings");
        Booking booking = bookings.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Instant booking not found"));
        if (booking.getStatus() != BookingStatus.SEARCHING || !live(booking)) throw new ResponseStatusException(HttpStatus.CONFLICT, "This booking has already been accepted or expired");
        if (booking.getPaymentStatus() != PaymentStatus.PAID) throw new ResponseStatusException(HttpStatus.CONFLICT, "Customer payment is pending");
        booking.assign(worker);
        Booking saved = bookings.saveAndFlush(booking);
        notifications.send(saved.getCustomer(), NotificationType.BOOKING, "Maid assigned", worker.getName()+" accepted your instant cleaning request.");
        notifications.send(worker, NotificationType.WORKER_ASSIGNMENT, "Instant booking accepted", "Open the booking to view full service details.");
        return view(saved);
    }

    @PostMapping("/{id}/reject")
    @Transactional
    public Map<String,Object> reject(@RequestHeader("Authorization") String header, @PathVariable Long id) {
        UserAccount worker = worker(header);
        if (!workerSafety.eligibleForDispatch(worker)) throw new ResponseStatusException(HttpStatus.CONFLICT, "You are not eligible to receive bookings");
        Booking booking = bookings.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Instant booking not found"));
        if (!live(booking) || booking.getStatus() != BookingStatus.SEARCHING)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This booking is no longer available");
        if (!rejections.existsByBookingIdAndWorkerId(id, worker.getId())) {
            rejections.save(new InstantRejection(id, worker.getId()));
        }
        return view(booking);
    }

    private boolean live(Booking booking) { if (booking.getExpiresAt()!=null && Instant.now().isAfter(booking.getExpiresAt())) { booking.expire(); bookings.save(booking); return false; } return true; }
    private UserAccount customer(String h) { UserAccount u=user(h); if(u.getRole()!=Role.CUSTOMER) throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Customer access required"); return u; }
    private UserAccount worker(String h) { UserAccount u=user(h); if(u.getRole()!=Role.WORKER) throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Worker access required"); return u; }
    private UserAccount user(String h) { return sessions.fromBearer(h).orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Please sign in")); }
    private Map<String,Object> view(Booking b) {
        Map<String,Object> result = new java.util.LinkedHashMap<>();
        result.put("id", b.getId()); result.put("service", b.getService()); result.put("services", List.of(b.getService()));
        result.put("address", b.getAddress()); result.put("pinCode", b.getPinCode()); result.put("scheduledFor", b.getScheduledFor());
        result.put("durationMinutes", b.getDurationMinutes()); result.put("optionLabel", b.getOptionLabel()); result.put("promoCode", "");
        result.put("discountPaise", 0); result.put("specialInstructions", b.getSpecialInstructions()); result.put("status", b.getStatus().name());
        result.put("paymentStatus", b.getPaymentStatus().name()); result.put("paymentAmountPaise", b.getPaymentAmountPaise());
        result.put("paymentMethod", b.getPaymentMethod()); result.put("customer", b.getCustomer().getName());
        result.put("worker", b.getWorker()==null ? "Unassigned" : b.getWorker().getName()); result.put("rating", 0);
        result.put("cancellationReason", ""); result.put("expiresAt", b.getExpiresAt()==null ? "" : b.getExpiresAt().toString());
        return result;
    }    record Request(@NotNull Long addressId, @Min(60) @Max(240) int durationMinutes, String instructions) {}
}