import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/main.dart';

void main() {
  testWidgets('renders the MVP title', (tester) async {
    await tester.pumpWidget(const MaidItQuickApp());
    expect(find.text('Home help\nin minutes.'), findsOneWidget);
  });
}
