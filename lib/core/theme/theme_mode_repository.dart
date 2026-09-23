import 'package:hive/hive.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';

/// テーマ設定のリポジトリ
///
/// Hive の settings ボックスに選択モードを保存・復元する
/// （本アプリの永続化は Hive が標準）。
class ThemeModeRepository {
  static const String _boxName = 'settings';
  static const String _key = 'book_review_theme_mode';

  const ThemeModeRepository();

  /// 保存されたテーマ設定を読み込む。未保存 / 不正値は null。
  Future<ThemeModeSetting?> loadThemeMode() async {
    final box = await Hive.openBox<String>(_boxName);
    final saved = box.get(_key);
    if (saved == null) return null;
    for (final mode in ThemeModeSetting.values) {
      if (mode.storageKey == saved) return mode;
    }
    return null;
  }

  /// テーマ設定を保存する。
  Future<void> saveThemeMode(ThemeModeSetting mode) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_key, mode.storageKey);
  }
}