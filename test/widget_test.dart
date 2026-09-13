// Basic Flutter widget test for Acadova app.

import 'package:flutter_test/flutter_test.dart';
import 'package:acadova/main.dart';

void main() {
  testWidgets('Acadova app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AcadovaApp());

    // Verify that Acadova text exists.
    expect(find.text('Acadova'), findsWidgets);

    // Fast-forward past the splash screen timer.
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
