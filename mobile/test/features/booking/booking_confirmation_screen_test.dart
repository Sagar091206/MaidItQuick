import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/core/brand_theme.dart';
import 'package:maiditquick_mobile/features/auth/data/auth_repository.dart';
import 'package:maiditquick_mobile/features/booking/presentation/booking_confirmation_screen.dart';

class _FakeApi extends ApiClient {
  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (path.startsWith('/bookings/')) {
      return {
        'id': 12,
        'service': 'Bathroom Cleaning',
        'services': ['Bathroom Cleaning'],
        'address': '12 Main Road',
        'pinCode': '712235',
        'scheduledFor': '2026-08-03T10:00:00',
        'durationMinutes': 60,
        'optionLabel': 'Standard service',
        'promoCode': '',
        'discountPaise': 0,
        'specialInstructions': '',
        'status': 'REQUESTED',
        'paymentStatus': 'PAID',
        'paymentAmountPaise': 188564,
        'paymentMethod': 'UPI',
        'paidAt': '2026-08-02T10:30:00',
        'customer': 'Riya',
        'worker': 'Unassigned',
        'rating': 0,
        'events': const [],
      };
    }
    return <String, dynamic>{};
  }
}

void main() {
  Future<void> pumpConfirmation(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: maidItQuickLightTheme(),
      home: BookingConfirmationScreen(
        api: _FakeApi(),
        session: const Session(token: 't', role: 'customer', name: 'Riya'),
        bookingId: 12,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the confirmed booking with payment and next steps',
      (tester) async {
    await pumpConfirmation(tester);

    expect(find.text('Booking MIQ-12 confirmed'), findsOneWidget);
    expect(find.text('1 · Partner assignment'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Amount paid'), 200);
    expect(find.text('Amount paid'), findsOneWidget);
    expect(find.text('₹1886'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Track booking'), 200);
    expect(find.text('Track booking'), findsOneWidget);
    expect(find.text('Back to dashboard'), findsOneWidget);
  });

  testWidgets('track booking opens the details screen', (tester) async {
    await pumpConfirmation(tester);

    await tester.scrollUntilVisible(find.text('Track booking'), 200);
    await tester.tap(find.text('Track booking'));
    await tester.pumpAndSettle();

    expect(find.text('Booking MIQ-12'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Payment'), 200);
    expect(find.text('Payment status'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('₹1886'), findsOneWidget);
  });
}
