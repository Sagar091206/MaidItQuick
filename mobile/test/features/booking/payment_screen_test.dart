import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/core/brand_theme.dart';
import 'package:maiditquick_mobile/features/auth/data/auth_repository.dart';
import 'package:maiditquick_mobile/features/booking/data/booking_repository.dart';
import 'package:maiditquick_mobile/features/booking/presentation/payment_screen.dart';

class _FakeApi extends ApiClient {
  final bool decline;

  _FakeApi({this.decline = false});

  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (path.startsWith('/bookings/')) {
      return {
        'id': 1,
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

  @override
  Future<dynamic> post(String path, Map<String, dynamic> body,
      {String? token}) async {
    if (path.endsWith('/pay-intent')) {
      return {
        'intentId': 42,
        'bookingId': 1,
        'reference': 'MIQ-PAY-1-000042',
        'amountPaise': 188564,
        'method': body['method'],
        'status': 'PENDING',
      };
    }
    if (path.endsWith('/pay')) {
      if (decline) {
        throw ApiException(
            'The payment was declined. Try another method or card.', 402);
      }
      return {
        'payment': {
          'id': 7,
          'reference': 'MIQ-PAY-1-000042',
          'method': body['method'],
          'amountPaise': 188564,
          'status': 'PAID',
          'gatewayResponse': 'Mock gateway approved (UPI riya@upi)',
          'completedAt': '2026-08-02T10:30:00',
        },
        'message': 'Payment successful',
      };
    }
    return <String, dynamic>{};
  }
}

void main() {
  final booking = CustomerBooking(
    id: 1,
    service: 'Bathroom Cleaning',
    services: const ['Bathroom Cleaning'],
    address: '12 Main Road',
    pinCode: '712235',
    scheduledFor: '2026-08-03T10:00:00',
    durationMinutes: 60,
    optionLabel: 'Standard service',
    promoCode: '',
    discountPaise: 0,
    specialInstructions: '',
    status: 'REQUESTED',
    paymentStatus: 'UNPAID',
    paymentAmountPaise: 188564,
    customer: 'Riya',
    worker: 'Unassigned',
    rating: 0,
  );

  Future<void> pumpPayment(WidgetTester tester, ApiClient api) async {
    await tester.pumpWidget(MaterialApp(
      theme: maidItQuickLightTheme(),
      home: PaymentScreen(
        api: api,
        session: const Session(token: 't', role: 'customer', name: 'Riya'),
        booking: booking,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the payable amount and payment methods', (tester) async {
    await pumpPayment(tester, _FakeApi());

    expect(find.text('Pay ₹1886'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Net banking'), findsOneWidget);
    expect(find.textContaining('simulated payment gateway'), findsOneWidget);
  });

  testWidgets('successful UPI payment routes to the confirmation screen',
      (tester) async {
    await pumpPayment(tester, _FakeApi());

    await tester.enterText(find.byType(TextField), 'riya@upi');
    await tester.tap(find.text('Pay ₹1886'));
    await tester.pumpAndSettle();

    expect(find.text('Booking MIQ-1 confirmed'), findsOneWidget);
    expect(find.text('1 · Partner assignment'), findsOneWidget);
  });

  testWidgets('declined payment shows the failure message and keeps the form',
      (tester) async {
    await pumpPayment(tester, _FakeApi(decline: true));

    await tester.enterText(find.byType(TextField), 'riya@upi');
    await tester.tap(find.text('Pay ₹1886'));
    await tester.pumpAndSettle();

    expect(find.textContaining('declined'), findsOneWidget);
    expect(find.text('Pay ₹1886'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
  });

  testWidgets('requires a UPI id before paying with UPI', (tester) async {
    await pumpPayment(tester, _FakeApi());

    await tester.tap(find.text('Pay ₹1886'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your UPI ID.'), findsOneWidget);
  });
}
