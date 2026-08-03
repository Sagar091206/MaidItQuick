import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/main.dart';

import 'helpers.dart';

void main() {
  setUp(() {
    mockPersistedStores();
  });

  testWidgets('renders the MVP title', (tester) async {
    await tester.pumpWidget(const MaidItQuickApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Home help\nin minutes.'), findsOneWidget);
  });
}
