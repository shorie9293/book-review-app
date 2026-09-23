import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/theme/app_theme.dart';
import 'package:book_review_app/core/theme/theme_mode_repository.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/screens/theme_mode_settings_screen.dart';

/// 親（イシコリ）の探針 — 合成の不変条件を撃つ。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_theme_mode_probe_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('settings');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('親探針: テーマ定義の対称性', () {
    test('AppTheme.light は light、AppTheme.dark は dark', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor),
      );
    });
  });

  group('親探針: Hive 往復と不正値', () {
    test('save → load は同じ設定を返す', () async {
      const repo = ThemeModeRepository();
      expect(await repo.loadThemeMode(), isNull);

      await repo.saveThemeMode(ThemeModeSetting.light);
      expect(await repo.loadThemeMode(), ThemeModeSetting.light);

      await repo.saveThemeMode(ThemeModeSetting.system);
      expect(await repo.loadThemeMode(), ThemeModeSetting.system);
    });

    test('不正な保存値は null を返し、fromStorageKey は system に落ちる', () async {
      final box = await Hive.openBox<String>('settings');
      await box.put('book_review_theme_mode', 'solar');
      const repo = ThemeModeRepository();
      expect(await repo.loadThemeMode(), isNull);
      expect(ThemeModeSetting.fromStorageKey('solar'), ThemeModeSetting.system);
    });
  });

  group('親探針: 画面 → onModeChanged の合成', () {
    testWidgets('ダークを選ぶと dark が通知される', (tester) async {
      final received = <ThemeModeSetting>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ThemeModeSettingsScreen(
            currentMode: ThemeModeSetting.system,
            onModeChanged: received.add,
          ),
        ),
      );

      await tester.tap(find.byKey(AppKeys.themeModeOption('dark')));
      await tester.pumpAndSettle();

      expect(received, [ThemeModeSetting.dark]);
    });
  });
}
