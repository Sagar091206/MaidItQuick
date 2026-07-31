import 'package:flutter_test/flutter_test.dart';

import 'package:maiditquick_mobile/main.dart';

import 'helpers.dart';

void main() {
  setUp(() {
    mockPersistedStores();
  });

  testWidgets('shows both onboarding journeys', (WidgetTester tester) async {
    await tester.pumpWidget(const MaidItQuickApp());
    await tester.pumpAndSettle();

    expect(find.text('Continue as customer'), findsOneWidget);
    expect(find.text('Continue as partner'), findsOneWidget);
  });
}
