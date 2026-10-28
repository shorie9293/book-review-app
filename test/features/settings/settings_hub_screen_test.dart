import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/infrastructure/app_lock_settings_screen.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/features/about/presentation/about_screen.dart';
import 'package:book_review_app/features/settings/presentation/settings_hub_screen.dart';
import 'package:book_review_app/screens/reduce_motion_settings_screen.dart';
import 'package:book_review_app/screens/text_scale_settings_screen.dart';
import 'package:book_review_app/screens/theme_mode_settings_screen.dart';

/// ハブに並ぶ項目の ID（実装と試練の唯一の合意点）。
const List<String> _itemIds = [
  'appearance',
  'text_scale',
  'reduce_motion',
  'app_lock',
  'reading_reminder',
  'quiet_hours',
  'backup',
  'about',
];

Widget _wrap(Widget child) => MaterialApp(home: child);

Future<void> _tapItem(WidgetTester tester, String id) async {
  final finder = find.byKey(AppKeys.settingsHubItem(id));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsHubScreen', () {
    testWidgets('全設定項目（8件）が一覧に表示される', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsHubScreen()));

      expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
      expect(find.text('設定'), findsOneWidget);

      for (final id in _itemIds) {
        final finder = find.byKey(AppKeys.settingsHubItem(id));
        await tester.scrollUntilVisible(finder, 80,
            scrollable: find.byType(Scrollable).first);
        expect(finder, findsOneWidget, reason: 'missing hub item: $id');
      }

      expect(find.text('テーマ'), findsOneWidget);
      expect(find.text('文字サイズ'), findsOneWidget);
      expect(find.text('アプリについて'), findsOneWidget);
    });

    testWidgets('各項目のタップで注入したビルダーが呼ばれる', (tester) async {
      final calls = <String, int>{};

      WidgetBuilder stub(String id) => (context) => Scaffold(
            appBar: AppBar(title: Text('stub_$id')),
            body: Center(child: Text('stub_body_$id')),
          );

      await tester.pumpWidget(_wrap(SettingsHubScreen(
        themeModeBuilder: (c) {
          calls['appearance'] = (calls['appearance'] ?? 0) + 1;
          return stub('appearance')(c);
        },
        textScaleBuilder: (c) {
          calls['text_scale'] = (calls['text_scale'] ?? 0) + 1;
          return stub('text_scale')(c);
        },
        reduceMotionBuilder: (c) {
          calls['reduce_motion'] = (calls['reduce_motion'] ?? 0) + 1;
          return stub('reduce_motion')(c);
        },
        appLockBuilder: (c) {
          calls['app_lock'] = (calls['app_lock'] ?? 0) + 1;
          return stub('app_lock')(c);
        },
        readingReminderBuilder: (c) {
          calls['reading_reminder'] = (calls['reading_reminder'] ?? 0) + 1;
          return stub('reading_reminder')(c);
        },
        quietHoursBuilder: (c) {
          calls['quiet_hours'] = (calls['quiet_hours'] ?? 0) + 1;
          return stub('quiet_hours')(c);
        },
        backupBuilder: (c) {
          calls['backup'] = (calls['backup'] ?? 0) + 1;
          return stub('backup')(c);
        },
        aboutBuilder: (c) {
          calls['about'] = (calls['about'] ?? 0) + 1;
          return stub('about')(c);
        },
      )));

      for (final id in _itemIds) {
        await _tapItem(tester, id);
        expect(calls[id], 1, reason: 'builder not called for $id');
        expect(find.text('stub_body_$id'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
      }
    });

    testWidgets('未指定ならテーマ設定の実画面が開き、値と変更が伝わる', (tester) async {
      final received = <ThemeModeSetting>[];
      await tester.pumpWidget(_wrap(SettingsHubScreen(
        themeMode: ThemeModeSetting.dark,
        onThemeModeChanged: received.add,
      )));

      await _tapItem(tester, 'appearance');

      expect(find.byType(ThemeModeSettingsScreen), findsOneWidget);
      final tile = tester.widget<RadioListTile<ThemeModeSetting>>(
        find.byKey(AppKeys.themeModeOption('dark')),
      );
      expect(tile.groupValue, ThemeModeSetting.dark);

      await tester.tap(find.byKey(AppKeys.themeModeOption('light')));
      await tester.pumpAndSettle();
      expect(received, [ThemeModeSetting.light]);
    });

    testWidgets('未指定なら文字サイズ設定の実画面が開き、値と変更が伝わる', (tester) async {
      final received = <double>[];
      await tester.pumpWidget(_wrap(SettingsHubScreen(
        textScale: TextScaleSetting.normalScale,
        onTextScaleChanged: received.add,
      )));

      await _tapItem(tester, 'text_scale');

      expect(find.byType(TextScaleSettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('text_scale_1.25')));
      await tester.pumpAndSettle();
      expect(received, [TextScaleSetting.largeScale]);
    });

    testWidgets('未指定なら「動きを減らす」実画面が開き、値と変更が伝わる', (tester) async {
      final received = <ReduceMotionSetting>[];
      await tester.pumpWidget(_wrap(SettingsHubScreen(
        reduceMotion: ReduceMotionSetting.off,
        onReduceMotionChanged: received.add,
        reduceMotionRepository: InMemoryReduceMotionRepository(),
      )));

      await _tapItem(tester, 'reduce_motion');

      expect(find.byType(ReduceMotionSettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reduce_motion_option_on')));
      await tester.pumpAndSettle();
      expect(received, [ReduceMotionSetting.on]);
    });

    testWidgets('未指定ならアプリロック設定の実画面が開く', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsHubScreen()));

      await _tapItem(tester, 'app_lock');

      expect(find.byType(AppLockSettingsScreen), findsOneWidget);
    });

    testWidgets('未指定なら「アプリについて」実画面が開き、戻るとハブへ帰る', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsHubScreen()));

      await _tapItem(tester, 'about');
      expect(find.byType(AboutScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
      expect(find.byType(AboutScreen), findsNothing);
    });

    testWidgets('バックアップは repository 未指定なら案内を出し、遷移しない', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsHubScreen()));

      await _tapItem(tester, 'backup');

      expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
      expect(find.text('バックアップは本棚のメニューから開けます'), findsOneWidget);
    });

    testWidgets('既存のテーマ設定画面からハブへ到達できる', (tester) async {
      await tester.pumpWidget(_wrap(ThemeModeSettingsScreen(
        currentMode: ThemeModeSetting.system,
        onModeChanged: (_) {},
      )));

      final entry = find.byKey(AppKeys.settingsHubEntry);
      expect(entry, findsOneWidget);

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsHubScreen), findsOneWidget);
      expect(find.text('設定'), findsOneWidget);
    });
  });
}
