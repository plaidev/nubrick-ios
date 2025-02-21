// This is a basic Flutter widget test.
//
import 'package:flutter_test/flutter_test.dart';

import 'package:e2e/main.dart';

void main() {
  testWidgets('remote config test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    expect(find.text('Not Found'), findsOneWidget);
  });
}
