# US-07 — Payment Workflow (Mock Gateway + Paid-Before-Assignment Gate)

> Master prompt: `00_MASTER_SYSTEM_PROMPT.md`. Prerequisites: US-05, US-06.
> Largest story. Backend: **1 migration**, **1 new package** (`com.makeitquick.payment`), **3 modified backend files**. Flutter: **2 modified data files**, **1 new screen**, **1 modified wizard file**.

## 1. Objective

Implement the MVP payment workflow:

1. Booking is created in `UNPAID` state — **no partner assignment happens yet**.
2. Customer opens the payment screen, chooses a method (UPI / Card / Net Banking), and pays through a **mock gateway** (simulated delay, deterministic failure for card number ending `0000`).
3. On success the booking becomes `PAID` and **automatic partner assignment fires** (`BookingAssignmentService`).
4. Customers see payment status everywhere (booking list, details, dashboard).

This replaces the current "no payment collected in MVP" behaviour and enforces the business rule *payment before assignment*.

## 2. Database migration (new file)

`server/db/manual/2026-08-02-booking-payments.sql`

```sql
-- Booking payments: payment columns on bookings + payments ledger table.
-- Run once on existing databases; fresh databases get the schema from the
-- Booking and Payment entities via Hibernate.

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'payment_status');
SET @sql := IF(@c = 0,
    "ALTER TABLE bookings ADD COLUMN payment_status VARCHAR(32) NOT NULL DEFAULT 'UNPAID'",
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'payment_method');
SET @sql := IF(@c = 0,
    'ALTER TABLE bookings ADD COLUMN payment_method VARCHAR(32) NULL',
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'payment_amount_paise');
SET @sql := IF(@c = 0,
    'ALTER TABLE bookings ADD COLUMN payment_amount_paise INT NULL',
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'paid_at');
SET @sql := IF(@c = 0,
    'ALTER TABLE bookings ADD COLUMN paid_at DATETIME(6) NULL',
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

CREATE TABLE IF NOT EXISTS payments (
    id              BIGINT NOT NULL AUTO_INCREMENT,
    booking_id      BIGINT NOT NULL,
    reference       VARCHAR(64) NOT NULL,
    method          VARCHAR(32) NOT NULL,
    amount_paise    INT NOT NULL,
    status          VARCHAR(32) NOT NULL,
    gateway_response VARCHAR(500),
    created_at      DATETIME(6) NOT NULL,
    completed_at    DATETIME(6) NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings (id)
) ENGINE = InnoDB;

SET @idx := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND INDEX_NAME = 'idx_payments_booking');
SET @add_idx := IF(@idx = 0,
    'ALTER TABLE payments ADD INDEX idx_payments_booking (booking_id)',
    'SELECT 1');
PREPARE s FROM @add_idx; EXECUTE s; DEALLOCATE PREPARE s;
```

## 3. Backend implementation

### 3.1 New package `com.makeitquick.payment`

**`PaymentStatus.java`**

```java
package com.makeitquick.payment;
public enum PaymentStatus { PENDING, PAID, FAILED, REFUNDED }
```

**`Payment.java`**

```java
package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "payments")
public class Payment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false) private Booking booking;
    @Column(nullable = false, length = 64) private String reference;
    @Column(nullable = false, length = 32) private String method;
    @Column(nullable = false) private int amountPaise;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 32)
    private PaymentStatus status = PaymentStatus.PENDING;
    @Column(length = 500) private String gatewayResponse;
    @Column(nullable = false, updatable = false) private Instant createdAt = Instant.now();
    private Instant completedAt;

    protected Payment() {}

    public Payment(Booking booking, String reference, String method, int amountPaise) {
        this.booking = booking;
        this.reference = reference;
        this.method = method;
        this.amountPaise = amountPaise;
    }

    public Long getId() { return id; }
    public Booking getBooking() { return booking; }
    public String getReference() { return reference; }
    public String getMethod() { return method; }
    public int getAmountPaise() { return amountPaise; }
    public PaymentStatus getStatus() { return status; }
    public String getGatewayResponse() { return gatewayResponse == null ? "" : gatewayResponse; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getCompletedAt() { return completedAt; }

    public void markPaid(String gatewayResponse) {
        this.status = PaymentStatus.PAID;
        this.gatewayResponse = gatewayResponse;
        this.completedAt = Instant.now();
    }

    public void markFailed(String gatewayResponse) {
        this.status = PaymentStatus.FAILED;
        this.gatewayResponse = gatewayResponse;
        this.completedAt = Instant.now();
    }
}
```

**`PaymentRepository.java`**

```java
package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
    List<Payment> findByBookingOrderByIdDesc(Booking booking);
    Optional<Payment> findByIdAndBooking(Long id, Booking booking);
    Optional<Payment> findTopByBookingOrderByIdDesc(Booking booking);
}
```

**`PaymentService.java`** — mock gateway + assignment trigger

```java
package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingAssignmentService;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingServiceRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PaymentService {
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
        bookings.save(booking);

        notifications.send(booking.getCustomer(), NotificationType.BOOKING,
                "Payment received",
                "We received ₹" + (intent.getAmountPaise() / 100) + " for booking " + booking.getService()
                        + ". A partner is being assigned.");
        assignBestWorker(booking);
        return Map.of(
                "payment", paymentView(intent),
                "message", "Payment successful");
    }

    /** Auto-assign a partner now that payment is complete (business rule). */
    private void assignBestWorker(Booking b) {
        if (b.getStatus() != BookingStatus.REQUESTED) return;
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

    private void simulateGatewayDelay() {
        try {
            Thread.sleep(1200);
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
```

**`PaymentController.java`**

```java
package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/bookings")
@CrossOrigin(origins = "*")
public class PaymentController {
    private final BookingRepository bookings;
    private final PaymentService payments;
    private final SessionResolver resolver;

    PaymentController(BookingRepository bookings, PaymentService payments, SessionResolver resolver) {
        this.bookings = bookings;
        this.payments = payments;
        this.resolver = resolver;
    }

    @PostMapping("/{id}/pay-intent")
    public Map<String, Object> intent(@RequestHeader("Authorization") String h,
                                      @PathVariable Long id,
                                      @Valid @RequestBody MethodInput input) {
        return payments.createIntent(ownBooking(h, id), input.method().toUpperCase());
    }

    @PostMapping("/{id}/pay")
    public Map<String, Object> pay(@RequestHeader("Authorization") String h,
                                   @PathVariable Long id,
                                   @Valid @RequestBody PayInput input) {
        return payments.pay(ownBooking(h, id), input.intentId(),
                input.method().toUpperCase(), input.upiId(), input.cardLast4(), input.bankName());
    }

    @GetMapping("/{id}/payment")
    public Map<String, Object> payment(@RequestHeader("Authorization") String h,
                                       @PathVariable Long id) {
        return payments.latest(ownBooking(h, id));
    }

    private Booking ownBooking(String header, Long id) {
        UserAccount user = resolver.fromBearer(header)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (user.getRole() != Role.CUSTOMER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer access required");
        }
        return bookings.findById(id)
                .filter(b -> b.getCustomer().getId().equals(user.getId()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found"));
    }

    record MethodInput(@NotBlank String method) {}
    record PayInput(@NotBlank String intentId,
                    @NotBlank String method,
                    String upiId,
                    @Pattern(regexp = "\\d{4}") String cardLast4,
                    String bankName) {}
}
```

### 3.2 Modify `Booking.java`

Add fields + accessors + a `markPaid` transition:

```java
@Enumerated(EnumType.STRING) @Column(nullable = false, length = 32)
private PaymentStatus paymentStatus = PaymentStatus.UNPAID;
private String paymentMethod;
private Integer paymentAmountPaise;
private Instant paidAt;

public PaymentStatus getPaymentStatus() { return paymentStatus; }
public String getPaymentMethod() { return paymentMethod == null ? "" : paymentMethod; }
public Integer getPaymentAmountPaise() { return paymentAmountPaise == null ? 0 : paymentAmountPaise; }
public Instant getPaidAt() { return paidAt; }

public void markPaid(String method, int amountPaise) {
    this.paymentStatus = PaymentStatus.PAID;
    this.paymentMethod = method;
    this.paymentAmountPaise = amountPaise;
    this.paidAt = Instant.now();
}
```

With `import com.makeitquick.payment.PaymentStatus;` — add `UNPAID` to the `PaymentStatus` enum too.

### 3.3 Modify `BookingAssignmentService.java`

Add the assign+notify orchestration (moved out of `BookingController` so payment can trigger it):

```java
import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.booking.Booking;

/** Assigns the best available worker and notifies both sides. */
public Optional<UserAccount> assignBest(Booking b, List<String> services, NotificationService notifications) {
    if (b.getStatus() != BookingStatus.REQUESTED) return Optional.empty();
    Optional<UserAccount> best = findBestWorker(services, b.getPinCode());
    if (best.isEmpty()) return Optional.empty();
    UserAccount worker = best.get();
    b.assign(worker);
    bookings.save(b);
    notifications.send(worker, NotificationType.WORKER_ASSIGNMENT, "New job assigned",
            "You have been assigned " + b.getService() + " for " + b.getScheduledFor() + ".");
    notifications.send(b.getCustomer(), NotificationType.BOOKING, "Worker assigned",
            "A partner has been assigned to your " + b.getService() + " booking.");
    return best;
}
```

> If `assignBest` cannot be injected cleanly due to circular dependencies (assignment → notifications), keep the orchestration in `PaymentService` (as drafted) and leave `BookingAssignmentService` with `findBestWorker` only. The key rule: **assignment is triggered only after `markPaid`**.

### 3.4 Modify `BookingController.java`

1. **Remove auto-assignment on create** — delete the `assignBestWorker(b, requested);` call (and its private method) in `create(...)`, and instead:

```java
notifications.send(u, NotificationType.BOOKING, "Payment required",
        "Complete the payment for your " + b.getService() + " booking so a partner can be assigned.");
```

2. **One-active-booking guard** at the top of `create(...)` (before saving):

```java
boolean hasActive = repo.findByCustomerIdOrderByIdDesc(u.getId()).stream()
        .anyMatch(b -> EnumSet.of(
                BookingStatus.REQUESTED, BookingStatus.ASSIGNED, BookingStatus.ACCEPTED,
                BookingStatus.ON_THE_WAY, BookingStatus.ARRIVED, BookingStatus.IN_PROGRESS)
                .contains(b.getStatus()));
if (hasActive) {
    throw new ResponseStatusException(HttpStatus.CONFLICT,
            "You already have an active booking. Complete or cancel it before booking again.");
}
```

3. **`view(...)` additions** (backward-compatible keys):

```java
result.put("paymentStatus", b.getPaymentStatus() == null ? "UNPAID" : b.getPaymentStatus().name());
result.put("paymentAmountPaise", b.getPaymentAmountPaise());
result.put("paymentMethod", b.getPaymentMethod());
result.put("paidAt", b.getPaidAt() == null ? null : b.getPaidAt().toString());
result.put("startOtpIssued", b.getStartOtpHash() != null);
result.put("endOtpIssued", b.getEndOtpHash() != null);
```

4. **Cancel gating:** `cancel(...)` should refund/flag when already paid — add to the existing guard block:

```java
if (b.getPaymentStatus() == com.makeitquick.payment.PaymentStatus.PAID) {
    // MVP: allow cancel; the refund is requested via /refund-request afterwards.
}
```

(no hard block — the refund-request endpoint already exists for cancelled bookings).

## 4. Flutter implementation

### 4.1 Extend `CustomerBooking` (modify `features/booking/data/booking_repository.dart`)

Add fields:

```dart
    this.paymentStatus = 'UNPAID',
    this.paymentAmountPaise = 0,
    this.paymentMethod = '',
    this.paidAt,
    this.startOtpIssued = false,
    this.endOtpIssued = false,
```

and parse:

```dart
        paymentStatus: json['paymentStatus'] as String? ?? 'UNPAID',
        paymentAmountPaise: (json['paymentAmountPaise'] as num?)?.toInt() ?? 0,
        paymentMethod: json['paymentMethod'] as String? ?? '',
        paidAt: json['paidAt'] as String?,
        startOtpIssued: json['startOtpIssued'] as bool? ?? false,
        endOtpIssued: json['endOtpIssued'] as bool? ?? false,
```

Helpers:

```dart
  bool get isPaid => paymentStatus == 'PAID';
  bool get needsPayment => !isPaid && isActive;
```

New models + methods in the same repository:

```dart
class PayIntent {
  const PayIntent({
    required this.intentId,
    required this.bookingId,
    required this.reference,
    required this.amountPaise,
    required this.method,
    required this.status,
  });

  factory PayIntent.fromJson(Map<String, dynamic> json) => PayIntent(
        intentId: (json['intentId'] as num).toInt(),
        bookingId: (json['bookingId'] as num).toInt(),
        reference: json['reference'] as String? ?? '',
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
        method: json['method'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );

  final int intentId;
  final int bookingId;
  final String reference;
  final int amountPaise;
  final String method;
  final String status;
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.reference,
    required this.method,
    required this.amountPaise,
    required this.status,
    required this.gatewayResponse,
    this.completedAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: (json['id'] as num?)?.toInt() ?? 0,
        reference: json['reference'] as String? ?? '',
        method: json['method'] as String? ?? '',
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        gatewayResponse: json['gatewayResponse'] as String? ?? '',
        completedAt: json['completedAt'] as String?,
      );

  final int id;
  final String reference;
  final String method;
  final int amountPaise;
  final String status;
  final String gatewayResponse;
  final String? completedAt;
}
```

Repository methods:

```dart
  Future<PayIntent> createPayIntent(String token, int id, String method) async {
    final payload = Map<String, dynamic>.from(await _api.post(
        '/bookings/$id/pay-intent', {'method': method}, token: token) as Map);
    return PayIntent.fromJson(payload);
  }

  Future<PaymentRecord> pay(
    String token, {
    required int bookingId,
    required int intentId,
    required String method,
    String upiId = '',
    String cardLast4 = '',
    String bankName = '',
  }) async {
    final payload = Map<String, dynamic>.from(await _api.post(
        '/bookings/$bookingId/pay',
        {
          'intentId': '$intentId',
          'method': method,
          if (upiId.isNotEmpty) 'upiId': upiId,
          if (cardLast4.isNotEmpty) 'cardLast4': cardLast4,
          if (bankName.isNotEmpty) 'bankName': bankName,
        },
        token: token) as Map);
    return PaymentRecord.fromJson(Map<String, dynamic>.from(payload['payment'] as Map));
  }

  Future<PaymentRecord> fetchPayment(String token, int bookingId) async {
    final payload = Map<String, dynamic>.from(
        await _api.get('/bookings/$bookingId/payment', token: token) as Map);
    return PaymentRecord.fromJson(payload);
  }
```

### 4.2 New file: `features/booking/presentation/payment_screen.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../data/booking_repository.dart';
import 'booking_details_screen.dart';

/// Payment step: method selection → mock gateway → success state.
/// US-08 replaces the inline success with BookingConfirmationScreen.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.api,
    required this.session,
    required this.booking,
  });

  final ApiClient api;
  final Session session;
  final CustomerBooking booking;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'UPI';
  final _upi = TextEditingController();
  final _card = TextEditingController();
  final _bank = TextEditingController();

  bool _processing = false;
  PaymentRecord? _paid;

  @override
  void dispose() {
    _upi.dispose();
    _card.dispose();
    _bank.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_method == 'UPI' && _upi.text.trim().isEmpty) {
      _showMessage('Enter your UPI ID.');
      return;
    }
    if (_method == 'CARD' && _card.text.trim().length < 4) {
      _showMessage('Enter your card number.');
      return;
    }
    if (_method == 'NETBANKING' && _bank.text.trim().isEmpty) {
      _showMessage('Choose your bank.');
      return;
    }
    setState(() => _processing = true);
    try {
      final repo = BookingRepository(widget.api);
      final intent =
          await repo.createPayIntent(widget.session.token, widget.booking.id, _method);
      final card4 = _card.text.trim().length >= 4
          ? _card.text.trim().substring(_card.text.trim().length - 4)
          : '';
      final record = await repo.pay(
        widget.session.token,
        bookingId: widget.booking.id,
        intentId: intent.intentId,
        method: _method,
        upiId: _upi.text.trim(),
        cardLast4: card4,
        bankName: _bank.text.trim(),
      );
      if (!mounted) return;
      setState(() => _paid = record);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _paid;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: paid != null ? _buildSuccess(paid) : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    final booking = widget.booking;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: context.brandCard,
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined,
                color: BrandColors.lime),
            title: Text('MIQ-${booking.id}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(booking.service),
            trailing: Text(formatPaise(booking.paymentAmountPaise),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Pay with',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        RadioGroup<String>(
          groupValue: _method,
          onChanged: (value) => setState(() => _method = value!),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'UPI',
                title: const Text('UPI'),
                subtitle: const Text('GPay, PhonePe, Paytm'),
                activeColor: BrandColors.lime,
              ),
              RadioListTile<String>(
                value: 'CARD',
                title: const Text('Card'),
                subtitle: const Text('Debit / credit (mock gateway)'),
                activeColor: BrandColors.lime,
              ),
              RadioListTile<String>(
                value: 'NETBANKING',
                title: const Text('Net banking'),
                activeColor: BrandColors.lime,
              ),
            ],
          ),
        ),
        if (_method == 'UPI') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _upi,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'yourname@upi',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
        ],
        if (_method == 'CARD') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _card,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Card number',
              hintText: 'Ending 0000 simulates a declined payment',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
          ),
        ],
        if (_method == 'NETBANKING') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _bank,
            decoration: const InputDecoration(
              labelText: 'Bank',
              hintText: 'HDFC, SBI, ICICI …',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _processing ? null : _pay,
          icon: _processing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_outline),
          label: Text(_processing
              ? 'Processing payment…'
              : 'Pay ${formatPaise(booking.paymentAmountPaise)}'),
        ),
        const SizedBox(height: 10),
        const Text(
          'This is a simulated payment gateway for the MVP. No real money moves.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: BrandColors.muted),
        ),
      ],
    );
  }

  Widget _buildSuccess(PaymentRecord record) {
    final booking = widget.booking;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        const Center(child: SuccessCheck()),
        const SizedBox(height: 20),
        const Center(
          child: Text('Payment successful',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'A partner will be assigned to your booking automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.brandMuted, height: 1.35),
          ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _PayRow(label: 'Booking', value: 'MIQ-${booking.id}'),
                _PayRow(label: 'Reference', value: record.reference),
                _PayRow(label: 'Method', value: record.method),
                _PayRow(label: 'Amount', value: formatPaise(record.amountPaise)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BookingDetailsScreen(
                api: widget.api,
                session: widget.session,
                bookingId: booking.id,
              ),
            ),
          ),
          icon: const Icon(Icons.track_changes_outlined),
          label: const Text('Track booking'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Back to dashboard'),
        ),
      ],
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.brandMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
```

### 4.3 Wizard handoff (modify `booking_wizard_screen.dart`)

Replace the `_createBooking` tail (the US-05 placeholder):

```dart
      final booking = await BookingRepository(widget.api).create(...);
      if (!mounted) return;
      // US-07: hand off to the payment screen. Pop the wizard first so the
      // back stack is clean: dashboard → payment → track.
      Navigator.of(context).pop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            api: widget.api,
            session: widget.session,
            booking: booking,
          ),
        ),
      );
```

(Remove the `_showMessage('Booking MIQ-... created.')` line; the payment screen is the new success path.)

## 5. UI states checklist (PaymentScreen)

- Loading → button spinner "Processing payment…".
- Error/decline → snackbar with server message; form stays intact for retry.
- Success → `SuccessCheck` + payment receipt card.
- Empty → N/A (booking always exists); amount always shown.

## 6. Tests

Backend (`server/src/test/java/.../PaymentControllerTest.java`):

- Create a booking via the API as a customer → `paymentStatus == UNPAID` and **worker is "Unassigned"** (no auto-assignment).
- `POST /api/bookings/{id}/pay-intent` → 200 with `intentId`.
- `POST /api/bookings/{id}/pay` with UPI → 200, `payment.status == PAID`, booking `paymentStatus == PAID`, and the worker is assigned (or booking stays REQUESTED when no worker is available).
- Card ending `0000` → 402, booking stays `UNPAID`.
- Double booking while one is active → 409.

Flutter: widget test for `PaymentScreen` with fake `ApiClient` asserting success flow shows the receipt; unit tests for `PaymentRecord.fromJson`.

## 7. Verification

```
cd D:\MaidItQuick\server
mvn -q compile && mvn test

cd D:\MaidItQuick\mobile
flutter analyze && flutter test
```

Manual QA: create booking → pay with UPI → dashboard shows assigned partner after refresh; pay with card `0000` → declined message; create second booking while first is active → "You already have an active booking".

## 8. Acceptance criteria

- [ ] Booking created as `UNPAID`; no assignment until payment.
- [ ] Mock gateway: methods UPI/CARD/NETBANKING, simulated delay, `0000` card fails.
- [ ] Payment success → booking `PAID` → automatic assignment + notifications.
- [ ] Payment status visible in booking payloads (list/detail/dashboard).
- [ ] One-active-booking guard returns 409.
- [ ] Refund-request endpoint still works for cancelled bookings.
