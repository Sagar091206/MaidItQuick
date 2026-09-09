import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/core/brand_theme.dart';
import 'package:maiditquick_mobile/features/auth/data/auth_repository.dart';
import 'package:maiditquick_mobile/features/booking/presentation/booking_details_screen.dart';

class _FakeBookingApi extends ApiClient {
  _FakeBookingApi({required this.initialStatus, this.optionLabel = 'Instant Maid'});

  String initialStatus;
  final String optionLabel;
  bool cancelCalled = false;
  String? cancelReason;
  String? cancelDetails;

  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (path.startsWith('/bookings/')) {
      return {
        'id': 92,
        'service': 'Basic Home Cleaning',
        'services': ['Basic Home Cleaning'],
        'address': '89/384, bangur park, rishra',
        'pinCode': '712248',
        'scheduledFor': '2026-09-09T10:00:00',
        'durationMinutes': 60,
        'optionLabel': optionLabel,
        'promoCode': '',
        'discountPaise': 0,
        'specialInstructions': '',
        'status': initialStatus,
        'paymentStatus': 'PAID',
        'paymentAmountPaise': 35282,
        'paymentMethod': 'CARD',
        'paidAt': '2026-09-09T09:30:00',
        'customer': 'rishi',
        'worker': 'Unassigned',
        'rating': 0,
        'cancellationReason': cancelReason ?? '',
        'cancellationStage': initialStatus == 'CANCELLED' ? 'BEFORE_ASSIGNMENT' : null,
        'refundStatus': initialStatus == 'CANCELLED' ? 'REQUESTED' : '',
        'refundAmountPaise': initialStatus == 'CANCELLED' ? 35282 : 0,
        'events': const [],
      };
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(String path, Map<String, dynamic> body, {String? token}) async {
    if (path == '/bookings/92/cancel') {
      cancelCalled = true;
      cancelReason = body['reason'] as String?;
      cancelDetails = body['details'] as String?;
      initialStatus = 'CANCELLED';
      return {
        'id': 92,
        'service': 'Basic Home Cleaning',
        'services': ['Basic Home Cleaning'],
        'address': '89/384, bangur park, rishra',
        'pinCode': '712248',
        'scheduledFor': '2026-09-09T10:00:00',
        'durationMinutes': 60,
        'optionLabel': optionLabel,
        'promoCode': '',
        'discountPaise': 0,
        'specialInstructions': '',
        'status': 'CANCELLED',
        'paymentStatus': 'PAID',
        'paymentAmountPaise': 35282,
        'paymentMethod': 'CARD',
        'paidAt': '2026-09-09T09:30:00',
        'customer': 'rishi',
        'worker': 'Unassigned',
        'rating': 0,
        'cancellationReason': cancelReason ?? '',
        'cancellationStage': 'BEFORE_ASSIGNMENT',
        'refundStatus': 'REQUESTED',
        'refundAmountPaise': 35282,
        'events': const [],
      };
    }
    return <String, dynamic>{};
  }
}

void main() {
  Future<void> pumpDetails(WidgetTester tester, _FakeBookingApi api) async {
    await tester.pumpWidget(MaterialApp(
      theme: maidItQuickLightTheme(),
      home: BookingDetailsScreen(
        api: api,
        session: const Session(token: 'token_xyz', role: 'customer', name: 'rishi'),
        bookingId: 92,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Instant Maid in SEARCHING stage displays Cancel booking and allows cancellation',
      (tester) async {
    final api = _FakeBookingApi(initialStatus: 'SEARCHING', optionLabel: 'Instant Maid');
    await pumpDetails(tester, api);

    expect(find.text('Booking MIQ-92'), findsOneWidget);
    expect(find.text('FINDING PARTNER'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Pending worker acceptance'), 200);
    expect(find.text('Pending worker acceptance'), findsOneWidget);

    // Scroll to find "Cancel booking" button
    await tester.scrollUntilVisible(find.text('Cancel booking'), 200);
    expect(find.text('Cancel booking'), findsOneWidget);

    // Tap "Cancel booking" button to open cancellation sheet
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    // Verify cancellation modal is displayed with title and 10 reasons
    expect(find.text('Please tell us why you need to cancel this booking.'), findsOneWidget);
    expect(find.text('Reason for cancellation'), findsOneWidget);
    expect(find.text('Confirm Cancel'), findsOneWidget);

    // Tap Confirm Cancel
    await tester.tap(find.text('Confirm Cancel'));
    await tester.pumpAndSettle();

    expect(api.cancelCalled, isTrue);
    expect(api.cancelReason, isNotEmpty);

    // Booking details view refreshes and shows cancelled status and notification
    expect(find.text('Booking cancelled'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CANCELLED'), -200);
    expect(find.text('CANCELLED'), findsOneWidget);
  });

  testWidgets('Scheduled booking in REQUESTED stage displays Cancel booking button',
      (tester) async {
    final api = _FakeBookingApi(initialStatus: 'REQUESTED', optionLabel: 'Standard service');
    await pumpDetails(tester, api);

    expect(find.text('REQUESTED'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cancel booking'), 200);
    expect(find.text('Cancel booking'), findsOneWidget);
  });

  testWidgets('Terminal states (EXPIRED, CANCELLED, COMPLETED) do not show Cancel booking button',
      (tester) async {
    for (final terminalStatus in ['EXPIRED', 'CANCELLED', 'COMPLETED']) {
      final api = _FakeBookingApi(initialStatus: terminalStatus);
      await pumpDetails(tester, api);

      expect(find.text('Cancel booking'), findsNothing);
    }
  });
}
