import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/screens/text_scale_settings_screen.dart';

void main() {
  Widget host(double initialScale, void Function(double) onScaleChanged) {
    return MaterialApp(
      home: TextScaleSettingsScreen(
        currentScale: initialScale,
        onScaleChanged: onScaleChanged,
      ),
    );
  }

  testWidgets('renders 3 options and sample card', (tester) async {
    await tester.pumpWidget(host(1.0, (_) {}));
    expect(find.text('文字サイズ設定'), findsOneWidget);
    expect(find.byKey(const Key('text_scale_0.9')), findsOneWidget);
    expect(find.byKey(const Key('text_scale_1.0')), findsOneWidget);
    expect(find.byKey(const Key('text_scale_1.25')), findsOneWidget);
    expect(find.textContaining('見本'), findsOneWidget);
  });

  testWidgets('tapping 大 updates the setting', (tester) async {
    double? changed;
    await tester.pumpWidget(
      host(1.0, (v) => changed = v),
    );

    await tester.tap(find.byKey(const Key('text_scale_1.25')));
    await tester.pump();

    expect(changed, 1.25);
  });

  testWidgets('selected state correct for initial 大', (tester) async {
    await tester.pumpWidget(host(1.25, (_) {}));

    final large = tester.widget<RadioListTile<double>>(
      find.byKey(const Key('text_scale_1.25')),
    );
    expect(large.groupValue, 1.25);
  });
}
