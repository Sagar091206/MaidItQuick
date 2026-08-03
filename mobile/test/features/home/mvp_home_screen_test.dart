import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/core/brand_theme.dart';
import 'package:maiditquick_mobile/features/auth/data/auth_repository.dart';
import 'package:maiditquick_mobile/features/home/presentation/mvp_home_screen.dart';
import 'package:maiditquick_mobile/shared/widgets/app_states.dart';

class _FakeApi extends ApiClient {
  _FakeApi({this.fail = false});

  final bool fail;

  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (fail) throw Exception('network down');
    if (path == '/customer/dashboard') {
      return {
        'welcomeName': 'Riya',
        'addresses': [
          {
            'id': 1,
            'label': 'Home',
            'address': '12 Main Road',
            'pinCode': '712235',
            'defaultAddress': true,
          },
        ],
        'services': [
          {'id': 1, 'name': 'Bathroom Cleaning', 'pricePaise': 79900},
          {'id': 2, 'name': 'Kitchen Cleaning', 'pricePaise': 89900},
        ],
        'activeBooking': {
          'id': 12,
          'service': 'Bathroom Cleaning',
          'address': '12 Main Road',
          'scheduledFor': '2026-08-03T10:00:00',
          'durationMinutes': 120,
          'status': 'ASSIGNED',
          'worker': 'Anita',
        },
        'recentBooking': null,
      };
    }
    return <String, dynamic>{};
  }
}

Widget _wrap(Widget child) => MaterialApp(
      theme: maidItQuickLightTheme(),
      home: child,
    );

void main() {
  testWidgets('shows skeleton then greeting and dashboard content',
      (tester) async {
    await tester.pumpWidget(_wrap(MvpHomeScreen(
      api: _FakeApi(),
      session: const Session(token: 't', role: 'customer', name: 'Riya'),
      onLogout: () {},
      onOpenSettings: () {},
      onBookService: () async {},
      onInstantMaid: () {},
      onOpenBookings: () {},
    )));

    expect(find.byType(SkeletonListView), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Hello, Riya'), findsOneWidget);
    expect(find.text('Bathroom Cleaning'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('shows the active booking hero with a track action',
      (tester) async {
    await tester.pumpWidget(_wrap(MvpHomeScreen(
      api: _FakeApi(),
      session: const Session(token: 't', role: 'customer', name: 'Riya'),
      onLogout: () {},
      onOpenSettings: () {},
      onBookService: () async {},
      onInstantMaid: () {},
      onOpenBookings: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Active booking'), findsOneWidget);
    expect(find.text('Track booking'), findsOneWidget);
    expect(find.text('ASSIGNED'), findsOneWidget);
  });

  testWidgets('shows error state with retry when the network fails',
      (tester) async {
    await tester.pumpWidget(_wrap(MvpHomeScreen(
      api: _FakeApi(fail: true),
      session: const Session(token: 't', role: 'customer', name: 'Riya'),
      onLogout: () {},
      onOpenSettings: () {},
      onBookService: () async {},
      onInstantMaid: () {},
      onOpenBookings: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('You are offline'), findsOneWidget);
  });
}
