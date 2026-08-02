# US-03 — Customer Dashboard (Premium Home)

> Master prompt: `00_MASTER_SYSTEM_PROMPT.md`. Prerequisites: US-01 (shared widgets), US-02 (shell).
> Modifies **one file**: `mobile/lib/features/home/presentation/mvp_home_screen.dart`. No backend change.

## 1. Objective

Upgrade the dashboard into a premium home screen: pulsing skeleton loading, service cards with icons, an active-booking hero card with a **Track** action, a saved-addresses strip, offline banner, and pull-to-refresh — all using the shared widgets from US-01 and the existing `GET /api/customer/dashboard` payload (no contract change).

## 2. Scope

- **In:** visuals and state handling in `mvp_home_screen.dart` only.
- **Out:** repository/DTO changes, backend changes, other screens.
- The **Track** button routes to the existing `BookingDetailsScreen` in this story; US-09 replaces the route with the richer `ActiveBookingScreen`.

## 3. Existing payload (already returned by `GET /api/customer/dashboard`)

```json
{
  "welcomeName": "Riya",
  "addresses": [ { "id": 1, "label": "Home", "address": "...", "pinCode": "700001", "defaultAddress": true } ],
  "services": [ { "id": 1, "name": "Bathroom Cleaning", "pricePaise": 79900 } ],
  "activeBooking": { "id": 12, "service": "Bathroom Cleaning", "address": "...", "scheduledFor": "...", "durationMinutes": 120, "status": "ASSIGNED", "worker": "Anita" },
  "recentBooking": { ... }
}
```

## 4. Implementation — Dart (`mvp_home_screen.dart`)

### 4.1 Add service icon mapping (presentation concern, no API change)

```dart
String serviceEmoji(String name) {
  final n = name.toLowerCase();
  if (n.contains('bath')) return '🛁';
  if (n.contains('kitchen')) return '🍳';
  if (n.contains('bed')) return '🛏️';
  if (n.contains('balcony')) return '🪴';
  if (n.contains('living')) return '🛋️';
  if (n.contains('deep') || n.contains('full')) return '✨';
  if (n.contains('dust')) return '🧹';
  if (n.contains('window')) return '🪟';
  return '🧽';
}
```

### 4.2 Replace the loading branch

Replace `? const Center(child: CircularProgressIndicator())` with a branded skeleton:

```dart
        child: _loading
            ? const SkeletonListView(itemCount: 5)
            : _error != null
                ? ErrorStateView(message: _error!, onRetry: _loadDashboard)
                : RefreshIndicator(
                    onRefresh: _loadDashboard,
                    child: _DashboardBody(
                      dashboard: _dashboard!,
                      search: _search,
                      services: _filteredServices,
                      onBookService: _openBookingFlow,
                      onTrackBooking: _openTrackBooking,
                      onOpenBookings: widget.onOpenBookings,
                    ),
                  ),
```

Add the handler:

```dart
  Future<void> _openTrackBooking(DashboardBooking booking) async {
    // US-09 swaps this route for ActiveBookingScreen.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(
          api: widget.api,
          session: widget.session,
          bookingId: booking.id,
        ),
      ),
    );
    if (mounted) await _loadDashboard();
  }
```

New imports:

```dart
import '../../booking/presentation/booking_details_screen.dart';
import '../../shared/widgets/app_states.dart';
```

### 4.3 `_DashboardBody` improvements

- Accept `onTrackBooking: ValueChanged<DashboardBooking>`.
- Hero greeting + "Book a service" button (unchanged).
- **Active booking hero card** when `activeBooking != null`:

```dart
        if (dashboard.activeBooking != null) ...[
          const SizedBox(height: 8),
          _ActiveBookingHero(
            booking: dashboard.activeBooking!,
            onTrack: () => onTrackBooking(dashboard.activeBooking!),
          ),
          const SizedBox(height: 24),
        ],
```

- Keep the services grid but render emoji + price:

```dart
              Text(serviceEmoji(service.name), style: const TextStyle(fontSize: 34)),
```

- Replace private `_StatusPill`/`_SectionHeader`/`_EmptyState`/`_DashboardError` usages with shared `StatusPill`/`SectionHeader`/`EmptyStateView`/`ErrorStateView` (delete the private classes from this file).
- If `_error != null`, the screen already shows `ErrorStateView`; offline detection lands in US-14 (statusCode == 0 → offline banner).

### 4.4 New private widget: active booking hero

```dart
class _ActiveBookingHero extends StatelessWidget {
  const _ActiveBookingHero({required this.booking, required this.onTrack});

  final DashboardBooking booking;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.radio_button_checked, color: scheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Active booking',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusPill(status: booking.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              booking.service,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${formatDateTime(booking.scheduledFor)} · ${booking.durationMinutes} min',
              style: TextStyle(color: context.brandMuted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onTrack,
              icon: const Icon(Icons.track_changes_outlined),
              label: const Text('Track booking'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 4.5 Keep the rest

Search field, saved-addresses strip, recent-booking card, and empty states stay as-is (swapped to shared widgets where possible).

## 5. UI states checklist

- Loading → `SkeletonListView`.
- Error → `ErrorStateView` with retry.
- Offline → US-14 adds the banner; the error path already covers the offline case gracefully.
- Empty → `EmptyStateView` for addresses, search results, recent bookings.
- Success → full dashboard + active-booking hero.
- Pull-to-refresh → already present, preserved.

## 6. Tests

`mobile/test/features/home/mvp_home_screen_test.dart` (new) — pump `MvpHomeScreen` with a mocked `ApiClient` (subclass overriding `get` to return a canned dashboard map) and assert: greeting renders, active hero appears, skeleton disappears after load. Example:

```dart
class _FakeApi extends ApiClient {
  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (path == '/customer/dashboard') {
      return {
        'welcomeName': 'Riya',
        'addresses': [],
        'services': [
          {'id': 1, 'name': 'Bathroom Cleaning', 'pricePaise': 79900},
        ],
        'activeBooking': null,
        'recentBooking': null,
      };
    }
    return <String, dynamic>{};
  }
}
```

## 7. Verification

```
cd D:\MaidItQuick\mobile
flutter analyze
flutter test test/features/home/mvp_home_screen_test.dart
```

## 8. Acceptance criteria

- [ ] Skeleton loading replaces the spinner.
- [ ] Active-booking hero with Track CTA.
- [ ] Service cards show emoji + name + price.
- [ ] Shared widgets replace private duplicates.
- [ ] Existing dashboard API contract untouched.
