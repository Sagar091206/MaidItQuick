import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/core/brand_theme.dart';
import 'package:maiditquick_mobile/features/auth/data/auth_repository.dart';
import 'package:maiditquick_mobile/features/booking/presentation/booking_wizard_screen.dart';
import 'package:maiditquick_mobile/shared/widgets/app_states.dart';

class _FakeApi extends ApiClient {
  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (path == '/services') {
      return [
        {'id': 1, 'name': 'Bathroom Cleaning', 'pricePaise': 79900, 'emoji': '🛁'},
        {'id': 2, 'name': 'Kitchen Cleaning', 'pricePaise': 89900, 'emoji': '🍳'},
      ];
    }
    if (path == '/customer/addresses') {
      return [
        {
          'id': 1,
          'label': 'Home',
          'address': '12 Main Road',
          'pinCode': '712235',
          'houseNumber': '12',
          'building': '',
          'street': 'Main Road',
          'area': 'Chinsurah',
          'landmark': '',
          'city': 'Hooghly',
          'state': 'West Bengal',
          'defaultAddress': true,
        },
      ];
    }
    if (path.startsWith('/availability')) {
      return {
        'status': 'AVAILABLE_NOW',
        'label': 'Available now',
        'message': 'MaidItQuick serves this PIN code.',
      };
    }
    if (path.startsWith('/booking/slots')) {
      return [
        {'time': '10:00', 'available': true},
        {'time': '14:00', 'available': true},
      ];
    }
    if (path.startsWith('/booking/quote')) {
      return {
        'currency': 'INR',
        'lines': [
          {'name': 'Bathroom Cleaning', 'pricePaise': 79900, 'amountPaise': 159800},
        ],
        'subtotalPaise': 159800,
        'promoCode': '',
        'discountPaise': 0,
        'totalPaise': 159800,
      };
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(String path, Map<String, dynamic> body,
      {String? token}) async {
    if (path == '/booking/calculate-duration') {
      final count = (body['services'] as List).length;
      return {'durationMinutes': count * 60, 'serviceCount': count};
    }
    return <String, dynamic>{};
  }
}

void main() {
  testWidgets('wizard walks address → services → schedule → summary with quote',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: maidItQuickLightTheme(),
      home: BookingWizardScreen(
        api: _FakeApi(),
        session: const Session(token: 't', role: 'customer', name: 'Riya'),
        onLogout: () {},
      ),
    ));

    expect(find.byType(SkeletonListView), findsOneWidget);
    await tester.pumpAndSettle();

    // Step 0: address.
    expect(find.text('1. Service address'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.textContaining('12 Main Road'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 1: tasks + duration.
    expect(find.text('2. Choose cleaning tasks'), findsOneWidget);
    expect(find.text('Bathroom Cleaning · ₹799'), findsOneWidget);
    expect(find.text('60 minutes for 1 task'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2: schedule.
    expect(find.text('3. Schedule'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 3: booking summary with the server quote.
    expect(find.text('4. Review booking'), findsOneWidget);
    expect(find.text('Bathroom Cleaning'), findsWidgets);
    await tester.drag(find.text('4. Review booking'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('₹1598'), findsWidgets);
    await tester.ensureVisible(find.text('Confirm booking'));
    expect(find.text('Confirm booking'), findsOneWidget);
  });
}
