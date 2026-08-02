# US-09 — Active Booking: Partner Assignment Display, Arrival & Live Tracking

> Master prompt: `00_MASTER_SYSTEM_PROMPT.md`. Prerequisites: US-07, US-08.
> Creates **one new file**; modifies **three files** (dashboard track route, confirmation track route, booking-details entry point).
> MVP constraint: continuous GPS tracking is **out of MVP scope** — "live tracking" here is **status-based**: polling the booking, an animated status stepper, partner card, arrival banner, and schedule/ETA information.

## 1. Objective

Build the customer's live booking screen:

- Polls `GET /api/bookings/{id}` every 10 s while the booking is active.
- Renders an animated **status stepper**: Requested → Assigned → On the way → Arrived → In progress → Completed.
- Shows the **assigned partner card** (name, avatar, role) once `ASSIGNED`; a **partner arrived** highlight banner at `ARRIVED`.
- Shows schedule, address, duration, payment status, timeline events, cancel/reschedule actions.
- **Arrival** step prompts the customer to check the Alerts tab for the **Start OTP** (the OTP card itself ships in US-10).

## 2. Files

| File | Action |
|---|---|
| `mobile/lib/features/booking/presentation/active_booking_screen.dart` | **New** |
| `mobile/lib/features/booking/presentation/booking_details_screen.dart` | Modify: for active statuses, render `ActiveBookingScreen` when the tile opens (or keep details and only add a banner linking to tracking) |
| `mobile/lib/features/home/presentation/mvp_home_screen.dart` | Modify: dashboard "Track booking" → `ActiveBookingScreen` (replacing `BookingDetailsScreen`) |
| `mobile/lib/features/booking/presentation/booking_confirmation_screen.dart` | Modify: "Track booking" → `ActiveBookingScreen` |

## 3. New file: `active_booking_screen.dart`

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../data/booking_repository.dart';

/// Live booking screen for active bookings. Polls the booking every 10 s and
/// renders status, partner card, arrival banner and the timeline.
/// US-10 adds the start/end OTP cards and the completion panel.
class ActiveBookingScreen extends StatefulWidget {
  const ActiveBookingScreen({
    super.key,
    required this.api,
    required this.session,
    required this.bookingId,
  });

  final ApiClient api;
  final Session session;
  final int bookingId;

  @override
  State<ActiveBookingScreen> createState() => _ActiveBookingScreenState();
}

class _ActiveBookingScreenState extends State<ActiveBookingScreen> {
  late final BookingRepository _repository;
  CustomerBooking? _booking;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _poll;

  static const _activeStatuses = {
    'REQUESTED', 'ASSIGNED', 'ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS',
  };

  static const _steps = ['REQUESTED', 'ASSIGNED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED'];

  @override
  void initState() {
    super.initState();
    _repository = BookingRepository(widget.api);
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking =
          await _repository.fetch(widget.session.token, widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = booking);
      if (_activeStatuses.contains(booking.status)) {
        _startPolling();
      } else {
        _poll?.cancel();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this booking.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      try {
        final booking =
            await _repository.fetch(widget.session.token, widget.bookingId);
        if (!mounted) return;
        setState(() => _booking = booking);
        if (!_activeStatuses.contains(booking.status)) _poll?.cancel();
      } catch (_) {
        // Silent: next poll or pull-to-refresh retries.
      }
    });
  }

  Future<void> _cancel() async {
    final booking = _booking;
    if (booking == null || !booking.canCancel) return;
    final reason = await _promptCancelReason();
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _repository
          .cancel(widget.session.token, booking.id, reason.trim());
      if (mounted) {
        setState(() => _booking = updated);
        _poll?.cancel();
        _showMessage('Booking cancelled');
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptCancelReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            hintText: 'Tell us why you are cancelling',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking ${booking == null ? '' : 'MIQ-${booking.id}'}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const SkeletonListView(itemCount: 5)
            : _error != null
                ? ErrorStateView(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _StatusStepper(status: booking!.status),
                        if (booking.status == 'ARRIVED') ...[
                          const SizedBox(height: 12),
                          _ArrivalBanner(),
                        ],
                        const SizedBox(height: 12),
                        if (booking.worker != 'Unassigned')
                          _PartnerCard(booking: booking),
                        const SizedBox(height: 12),
                        _InfoCard(booking: booking),
                        const SizedBox(height: 12),
                        _TimelineCard(events: booking.events),
                        const SizedBox(height: 18),
                        if (booking.canReschedule)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _showMessage(
                                'Rescheduling is available only before a partner is assigned.'),
                            icon: const Icon(Icons.event_available_outlined),
                            label: const Text('Reschedule'),
                          ),
                        if (booking.canCancel) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _cancel,
                            icon: const Icon(Icons.cancel_outlined),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                            label: const Text('Cancel booking'),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Animated five/four-step status stepper.
class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final steps = ['REQUESTED', 'ASSIGNED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED'];
    final currentIndex = steps.indexOf(status);
    final scheme = context.scheme;
    final activeUntil = currentIndex < 0 ? steps.length : currentIndex;

    return Card(
      color: context.brandCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text(bookingStatusLabel(status),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: _StepDot(
                      label: _stepLabel(steps[i]),
                      active: i <= activeUntil,
                      current: i == currentIndex,
                      isLast: i == steps.length - 1,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _stepLabel(String status) => switch (status) {
        'REQUESTED' => 'Confirmed',
        'ASSIGNED' => 'Assigned',
        'ON_THE_WAY' => 'On the way',
        'ARRIVED' => 'Arrived',
        'IN_PROGRESS' => 'In progress',
        'COMPLETED' => 'Done',
        _ => status,
      };
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.active,
    required this.current,
    required this.isLast,
  });

  final String label;
  final bool active;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = active ? scheme.primary : scheme.outlineVariant;
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: current ? 16 : 12,
                height: current ? 16 : 12,
                decoration: BoxDecoration(
                  color: active ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  color: active ? scheme.onSurface : context.brandMuted,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: active ? color : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

class _ArrivalBanner extends StatelessWidget {
  const _ArrivalBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.doorbell_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Your partner has arrived. Share the start OTP from the Alerts tab when the service begins.',
                style: TextStyle(fontWeight: FontWeight.w700, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.booking});

  final CustomerBooking booking;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      color: context.brandCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.person, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your partner',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                  const SizedBox(height: 2),
                  Text(booking.worker,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    _partnerStateLabel(booking.status),
                    style: TextStyle(color: context.brandMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.verified_user_outlined, color: scheme.primary),
          ],
        ),
      ),
    );
  }

  String _partnerStateLabel(String status) => switch (status) {
        'ASSIGNED' => 'Assigned — awaiting acceptance',
        'ACCEPTED' => 'Accepted the job',
        'ON_THE_WAY' => 'Travelling to your address',
        'ARRIVED' => 'At your location',
        'IN_PROGRESS' => 'Working at your home',
        _ => 'Assigned',
      };
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.booking});

  final CustomerBooking booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.brandCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, Icons.schedule_outlined, 'Schedule',
                formatDateTime(booking.scheduledFor)),
            _row(context, Icons.location_on_outlined, 'Address', booking.address),
            _row(context, Icons.timer_outlined, 'Duration',
                '${booking.durationMinutes} minutes'),
            _row(
              context,
              Icons.payments_outlined,
              'Payment',
              booking.isPaid
                  ? '${formatPaise(booking.paymentAmountPaise)} · paid'
                  : 'Pending',
            ),
            if (booking.specialInstructions.isNotEmpty)
              _row(context, Icons.notes_outlined, 'Notes',
                  booking.specialInstructions),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.scheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(label, style: TextStyle(color: context.brandMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<BookingEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Card(
      color: context.brandCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Timeline',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle,
                        size: 10, color: context.scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.note,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            formatDateTime(event.createdAt),
                            style: TextStyle(
                                color: context.brandMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

## 4. Route swaps

### 4.1 `mvp_home_screen.dart` (dashboard)

`_openTrackBooking` → push `ActiveBookingScreen(api: widget.api, session: widget.session, bookingId: booking.id)` (replace `BookingDetailsScreen` import/route).

### 4.2 `booking_confirmation_screen.dart`

`_track()` → push `ActiveBookingScreen` (replace `BookingDetailsScreen`).

### 4.3 `booking_details_screen.dart` (history entry point)

Add a banner at the top of the details body when the booking is active:

```dart
        if (booking.isActive)
          Card(
            color: context.scheme.primaryContainer,
            child: ListTile(
              leading: Icon(Icons.track_changes_outlined,
                  color: context.scheme.primary),
              title: const Text('This booking is live'),
              subtitle: const Text('Open live tracking for status updates.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ActiveBookingScreen(
                    api: widget.api,
                    session: widget.session,
                    bookingId: booking.id,
                  ),
                ),
              ),
            ),
          ),
```

(`widget.api`/`widget.session` are already available in `_DetailsBody`'s callers — pass them down or use the parent's fields; the existing `BookingDetailsScreen` already owns both.)

## 5. UI states checklist

- Loading → skeleton; Error/retry → `ErrorStateView`; polling failure → silent + manual refresh; Empty timeline → hidden; Success → stepper + partner card + info + timeline; arrival → highlight banner; completed → stepper completes (US-10 adds the completion panel).

## 6. Tests

Widget test (new): fake `ApiClient` returns booking at `ASSIGNED`; assert "Your partner" card shows the worker name; returns `ARRIVED` on second fetch; use `tester.pump(Duration(seconds: 10))` to advance polling and assert the arrival banner appears.

## 7. Verification

```
cd D:\MaidItQuick\mobile
flutter analyze && flutter test
```

Manual QA: create+pay a booking; watch the stepper advance as the worker (second device/admin) moves it through `ASSIGNED → ACCEPTED → ON_THE_WAY → ARRIVED → IN_PROGRESS`.

## 8. Acceptance criteria

- [ ] Stepper animates through all statuses; polling every 10 s.
- [ ] Partner card appears after assignment; arrival banner at `ARRIVED`.
- [ ] Payment status shown; cancel still gated by business rules.
- [ ] Dashboard/confirmation track routes point here.
- [ ] No GPS dependency (MVP scope respected).
