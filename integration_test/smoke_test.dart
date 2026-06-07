import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:book_review_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('basic smoke test', (WidgetTester tester) async {
    // Start the app
    app.main();
    await tester.pumpAndSettle();

    // Expect the main screen to contain a widget with key 'home_screen'
    expect(find.byKey(const ValueKey('home_screen')), findsOneWidget);
  });
}
