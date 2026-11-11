import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/help/presentation/help_screen.dart';
import 'package:book_review_app/features/settings/presentation/settings_hub_screen.dart';

/// ヘルプ追加前から存在する項目（順序も含めて不変であること）。
const List<String> _preExistingIds = [
  'crash_log',
  'appearance',
  'text_scale',
  'reduce_motion',
  'app_lock',
  'reading_reminder',
  'quiet_hours',
  'backup',
  'about',
  'auto_backup',
];

Widget _wrap(Widget child) => MaterialApp(home: child);

/// 全項目が同時に build されるよう縦長の画面で描画する。
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('SettingsHubScreen のヘルプ導線', () {
    testWidgets('ヘルプ項目がちょうど1つ表示される', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsHubScreen()));
      await tester.pumpAndSettle();

      final entry = find.byKey(AppKeys.settingsHubItem('help'));
      await tester.scrollUntilVisible(entry, 80,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();

      expect(entry, findsOneWidget);
      expect(find.text('遊び方・ヘルプ'), findsOneWidget);
    });

    testWidgets('タップで HelpScreen が開き、戻るとハブへ帰る', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsHubScreen()));
      await tester.pumpAndSettle();

      final entry = find.byKey(AppKeys.settingsHubItem('help'));
      await tester.scrollUntilVisible(entry, 80,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(HelpScreen), findsOneWidget);
      expect(find.byKey(AppKeys.helpScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
      expect(find.byType(HelpScreen), findsNothing);
    });

    testWidgets('既存項目の数と並び順は変わらない', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_wrap(const SettingsHubScreen()));
      await tester.pumpAndSettle();

      final keys = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.key as ValueKey<String>?)?.value)
          .whereType<String>()
          .where((k) => k.startsWith('settings_hub_item_'))
          .toList();

      // 既存10件は元の相対順のまま存在する。
      final existing = keys
          .where((k) => k != 'settings_hub_item_help')
          .where((k) => k != 'settings_hub_item_cross_app_link')
          .map((k) => k.replaceFirst('settings_hub_item_', ''))
          .toList();
      expect(existing, _preExistingIds);

      // ヘルプは1本だけ。
      expect(
        keys.where((k) => k == 'settings_hub_item_help').length,
        1,
      );

      // 連携状況も1本だけ（項目追加はこの1本に限る）。
      expect(
        keys.where((k) => k == 'settings_hub_item_cross_app_link').length,
        1,
      );
    });
  });
}
