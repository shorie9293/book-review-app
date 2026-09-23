import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/theme/theme_mode_repository.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_theme_mode_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('settings');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('ThemeModeRepository (Hive)', () {
    test('loadThemeMode returns null when unset', () async {
      final repo = ThemeModeRepository();
      expect(await repo.loadThemeMode(), isNull);
    });

    test('save + load round-trip for all modes', () async {
      final repo = ThemeModeRepository();
      for (final mode in ThemeModeSetting.values) {
        await repo.saveThemeMode(mode);
        expect(await repo.loadThemeMode(), mode);
      }
    });

    test('loadThemeMode returns null for invalid stored value', () async {
      final repo = ThemeModeRepository();
      final box = await Hive.openBox<String>('settings');
      await box.put('book_review_theme_mode', 'invalid');
      expect(await repo.loadThemeMode(), isNull);
    });
  });
}