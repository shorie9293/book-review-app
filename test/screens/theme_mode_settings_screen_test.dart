import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/screens/theme_mode_settings_screen.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';

void main() {
  Widget host(
    ThemeModeSetting initialMode,
    void Function(ThemeModeSetting) onModeChanged,
  ) {
    return MaterialApp(
      home: ThemeModeSettingsScreen(
        currentMode: initialMode,
        onModeChanged: onModeChanged,
      ),
    );
  }

  testWidgets('renders title and 3 options', (tester) async {
    await tester.pumpWidget(host(ThemeModeSetting.system, (_) {}));
    expect(find.text('テーマ設定'), findsOneWidget);
    expect(find.text('ライト'), findsOneWidget);
    expect(find.text('ダーク'), findsOneWidget);
    expect(find.text('システム'), findsOneWidget);
  });

  testWidgets('tapping ダーク calls onModeChanged with dark', (tester) async {
    ThemeModeSetting? changed;
    await tester.pumpWidget(
      host(ThemeModeSetting.light, (m) => changed = m),
    );

    await tester.tap(find.byKey(const Key('theme_mode_option_dark')));
    await tester.pump();

    expect(changed, ThemeModeSetting.dark);
  });

  testWidgets('selected state correct for initial system', (tester) async {
    await tester.pumpWidget(host(ThemeModeSetting.system, (_) {}));

    final tile = tester.widget<RadioListTile<ThemeModeSetting>>(
      find.byKey(const Key('theme_mode_option_system')),
    );
    expect(tile.groupValue, ThemeModeSetting.system);
  });
}