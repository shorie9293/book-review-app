import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/core/theme/text_scale_repository.dart';
import 'package:book_review_app/core/theme/theme_mode_repository.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';

/// 回帰試練: 3つの設定リポジトリが同一 Hive box を異なる型で開くと
/// `HiveError: The box "settings" is already open and of type Box<double>.`
/// で起動時に落ちる（CI の integration smoke が検出した実バグ）。
///
/// 文字サイズ（double）は 'settings_scalars'、文字列系は 'settings' に
/// 分離されているため、main.dart と同じ順序で load しても例外にならない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_box_conflict_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('3リポジトリを main.dart と同じ順で load しても例外にならない', () async {
    // main.dart の initState と同じ順序（text scale → theme → reduce motion）。
    expect(await const TextScaleRepository().loadScale(), isNull);
    expect(await const ThemeModeRepository().loadThemeMode(), isNull);
    expect(await const ReduceMotionRepository().load(), isNull);

    // 型が固定された後でも、各リポジトリの保存が通ること。
    await const TextScaleRepository().saveScale(1.25);
    await const ThemeModeRepository().saveThemeMode(ThemeModeSetting.dark);
    await const ReduceMotionRepository().save(ReduceMotionSetting.on);

    expect(await const TextScaleRepository().loadScale(), 1.25);
    expect(
      await const ThemeModeRepository().loadThemeMode(),
      ThemeModeSetting.dark,
    );
    expect(await const ReduceMotionRepository().load(), ReduceMotionSetting.on);
  });

  test('text scale の save → load 往復', () async {
    const repo = TextScaleRepository();
    await repo.saveScale(0.9);
    expect(await repo.loadScale(), 0.9);

    await repo.saveScale(1.25);
    expect(await repo.loadScale(), 1.25);
  });

  test('theme mode の save → load 往復', () async {
    const repo = ThemeModeRepository();
    await repo.saveThemeMode(ThemeModeSetting.light);
    expect(await repo.loadThemeMode(), ThemeModeSetting.light);

    await repo.saveThemeMode(ThemeModeSetting.dark);
    expect(await repo.loadThemeMode(), ThemeModeSetting.dark);
  });

  test('reduce motion の save → load 往復', () async {
    const repo = ReduceMotionRepository();
    await repo.save(ReduceMotionSetting.off);
    expect(await repo.load(), ReduceMotionSetting.off);

    await repo.save(ReduceMotionSetting.on);
    expect(await repo.load(), ReduceMotionSetting.on);
  });

  test('文字サイズと文字列設定が別 box に保存される', () async {
    await const TextScaleRepository().saveScale(1.25);
    await const ThemeModeRepository().saveThemeMode(ThemeModeSetting.dark);

    expect(Hive.isBoxOpen(TextScaleRepository.boxName), isTrue);
    expect(Hive.isBoxOpen('settings'), isTrue);
    expect(TextScaleRepository.boxName, isNot('settings'));
  });
}
