import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/brand_theme.dart';
import 'package:maiditquick_mobile/shared/widgets/app_states.dart';

void main() {
  testWidgets('StatusPill renders the label without underscores',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: maidItQuickLightTheme(),
      home: const Scaffold(body: StatusPill(status: 'ON_THE_WAY')),
    ));
    expect(find.text('ON THE WAY'), findsOneWidget);
  });

  testWidgets('EmptyStateView shows title, message and action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: maidItQuickLightTheme(),
      home: Scaffold(
        body: EmptyStateView(
          icon: Icons.history,
          title: 'Nothing yet',
          message: 'Book a service first.',
          actionLabel: 'Book now',
          onAction: () {},
        ),
      ),
    ));
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Book a service first.'), findsOneWidget);
    expect(find.text('Book now'), findsOneWidget);
  });

  testWidgets('OfflineBanner shows retry action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: maidItQuickLightTheme(),
      home: const Scaffold(body: OfflineBanner(onRetry: null)),
    ));
    expect(find.textContaining('You are offline'), findsOneWidget);
  });

  test('formatPaise converts paise to rupees', () {
    expect(formatPaise(12500), '₹125');
    expect(formatPaise(5000), '₹50');
  });

  test('bookingStatusLabel maps statuses to friendly labels', () {
    expect(bookingStatusLabel('ON_THE_WAY'), 'Partner on the way');
    expect(bookingStatusLabel('WEIRD'), 'WEIRD');
  });

  test('formatDateTime renders a local date time', () {
    expect(formatDateTime('2026-08-02T10:00:00'), '02/08/2026, 10:00 AM');
  });
}
