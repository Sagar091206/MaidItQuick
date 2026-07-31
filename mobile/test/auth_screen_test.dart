import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/main.dart';

import 'helpers.dart';

void main() {
  setUp(() {
    mockPersistedStores();
  });

  testWidgets('customer auth screen shows premium sign-in elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaidItQuickApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as customer'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to MaidItQuick'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mobile number'),
        findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
  });

  testWidgets('customer send-otp button gates on a valid number',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaidItQuickApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as customer'));
    await tester.pumpAndSettle();

    final sendOtp = find.widgetWithText(FilledButton, 'Send OTP');
    expect(tester.widget<FilledButton>(sendOtp).enabled, isFalse);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile number'), '123');
    await tester.pump();
    expect(tester.widget<FilledButton>(sendOtp).enabled, isFalse);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile number'), '9876543210');
    await tester.pump();
    expect(tester.widget<FilledButton>(sendOtp).enabled, isTrue);
  });
}
