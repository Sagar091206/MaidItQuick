package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingAssignmentService;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingServiceRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Mock-gateway payment workflow for the MVP.
 *
 * <p>Creates a payment intent per attempt, simulates a gateway round trip and
 * marks the attempt paid or failed. A successful payment flips the booking to
 * PAID and only then triggers partner assignment (business rule: payment
 * before assignment). Declined and duplicate attempts never create duplicate
 * bookings, and a booking whose unpaid session expired cannot be paid.</p>
 */
@Service
public class PaymentService {

    /** Unpaid bookings expire after this window; payment is refused afterwards. */
    public static final Duration UNPAID_TIMEOUT = Duration.ofHours(24);

    private static final long GATEWAY_DELAY_MILLIS = 1200;

    private final PaymentRepository payments;
    private final BookingRepository bookings;
    private final BookingServiceRepository bookingServices;
    private final BookingAssignmentService assigner;
    private final NotificationService notifications;
    private final SecureRandom random = new SecureRandom();

    PaymentService(PaymentRepository payments, BookingRepository bookings,
                   BookingServiceRepository bookingServices,
                   BookingAssignmentService assigner, NotificationService notifications) {
        this.payments = payments;
        this.bookings = bookings;
        this.bookingServices = bookingServices;
        this.assigner = assigner;
        this.notifications = notifications;
    }

    public Map<String, Object> createIntent(Booking booking, String method) {
        requireUnpaid(booking);
        requireNotExpired(booking);
        int amount = booking.getPaymentAmountPaise() != null ? booking.getPaymentAmountPaise() : 0;
        if (amount <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Payment amount is missing. Recreate the booking.");
        }
        String reference = "MIQ-PAY-" + booking.getId() + "-" + String.format("%06d", random.nextInt(1_000_000));
        Payment intent = payments.save(new Payment(booking, reference, method, amount));
        return Map.of(
                "intentId", intent.getId(),
                "bookingId", booking.getId(),
                "reference", reference,
                "amountPaise", amount,
                "method", method,
                "status", intent.getStatus().name());
    }

    @Transactional
    public Map<String, Object> pay(Booking booking, String intentId, String method,
                                   String upiId, String cardLast4, String bankName) {
        requireNotExpired(booking);
        Payment intent = payments.findByIdAndBooking(Long.parseLong(intentId), booking)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Payment intent not found"));
        if (intent.getStatus() != PaymentStatus.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This payment was already processed");
        }

        // ── Mock gateway ────────────────────────────────────────────────────
        // Real gateways are out of MVP scope. The mock fails only when a card
        // number ending in 0000 is provided, so QA can exercise the failure path.
        simulateGatewayDelay();
        boolean declined = "CARD".equalsIgnoreCase(method) && "0000".equalsIgnoreCase(cardLast4);
        // ────────────────────────────────────────────────────────────────────

        if (declined) {
            intent.markFailed("Mock gateway declined the card");
            payments.save(intent);
            notifications.send(booking.getCustomer(), NotificationType.BOOKING,
                    "Payment failed",
                    "Your payment for " + booking.getService() + " could not be completed. Please try again.");
            throw new ResponseStatusException(HttpStatus.PAYMENT_REQUIRED,
                    "The payment was declined. Try another method or card.");
        }

        intent.markPaid("Mock gateway approved (" + method
                + (upiId != null && !upiId.isBlank() ? " " + upiId : "")
                + (cardLast4 != null && !cardLast4.isBlank() ? " ••••" + cardLast4 : "")
                + (bankName != null && !bankName.isBlank() ? " " + bankName : "") + ")");
        payments.save(intent);

        booking.markPaid(method, intent.getAmountPaise());
        Booking paid = bookings.save(booking);

        notifications.send(paid.getCustomer(), NotificationType.BOOKING,
                "Payment received",
                "We received ₹" + (intent.getAmountPaise() / 100) + " for booking " + paid.getService()
                        + ". A partner is being assigned.");
        assignBestWorker(paid);
        return Map.of(
                "payment", paymentView(intent),
                "message", "Payment successful");
    }

    /** Auto-assign a partner now that payment is complete (business rule). */
    private void assignBestWorker(Booking b) {
        if (b.getPaymentStatus() != PaymentStatus.PAID) return;
        List<String> services = bookingServices.findByBookingIdOrderByIdAsc(b.getId()).stream()
                .map(com.makeitquick.booking.BookingService::getServiceName).toList();
        assigner.assignBest(b, services, notifications);
    }

    public Map<String, Object> latest(Booking booking) {
        return payments.findTopByBookingOrderByIdDesc(booking)
                .map(this::paymentView)
                .orElseGet(() -> Map.of("status", "UNPAID"));
    }

    private void requireUnpaid(Booking booking) {
        if (booking.getPaymentStatus() == PaymentStatus.PAID) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This booking is already paid");
        }
    }

    private void requireNotExpired(Booking booking) {
        if (booking.getPaymentStatus() != PaymentStatus.PAID
                && booking.getExpiresAt() != null
                && !booking.getExpiresAt().isAfter(Instant.now())) {
            throw new ResponseStatusException(HttpStatus.GONE,
                    "This instant booking request has expired. Please create a new request.");
        }
        if (booking.getPaymentStatus() != PaymentStatus.PAID
                && booking.getCreatedAt() != null
                && Duration.between(booking.getCreatedAt(), Instant.now()).compareTo(UNPAID_TIMEOUT) > 0) {
            throw new ResponseStatusException(HttpStatus.GONE,
                    "Your payment session expired. Please book again.");
        }
    }

    private void simulateGatewayDelay() {
        try {
            Thread.sleep(GATEWAY_DELAY_MILLIS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private Map<String, Object> paymentView(Payment payment) {
        return Map.of(
                "id", payment.getId(),
                "reference", payment.getReference(),
                "method", payment.getMethod(),
                "amountPaise", payment.getAmountPaise(),
                "status", payment.getStatus().name(),
                "gatewayResponse", payment.getGatewayResponse(),
                "createdAt", payment.getCreatedAt().toString(),
                "completedAt", payment.getCompletedAt() == null ? null : payment.getCompletedAt().toString());
    }
}
