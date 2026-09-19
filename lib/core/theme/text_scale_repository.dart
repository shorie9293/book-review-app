import 'package:hive/hive.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';

/// 文字サイズ（UIスケール）設定のリポジトリ
///
/// Hive の settings ボックスにスケール倍率を保存・復元する
/// （本アプリの永続化は Hive が標準）。
/// アプリ全体のテキストは [TextScaler.linear] で拡大縮小される
/// （MaterialApp.builder の MediaQuery で上書き）。
class TextScaleRepository {
  static const String _boxName = 'settings';
  static const String _key = 'book_review_text_scale';

  const TextScaleRepository();

  /// 保存されたスケール倍率を読み込む。未保存は null（=1.0 扱い）。
  Future<double?> loadScale() async {
    final box = await Hive.openBox<double>(_boxName);
    final value = box.get(_key);
    if (value == null) return null;
    return TextScaleSetting.isAllowed(value) ? value : null;
  }

  /// スケール倍率を保存する（許可外の値は ArgumentError）。
  Future<void> saveScale(double scale) async {
    if (!TextScaleSetting.isAllowed(scale)) {
      throw ArgumentError.value(scale, 'scale', '許可されていない文字サイズ倍率');
    }
    final box = await Hive.openBox<double>(_boxName);
    await box.put(_key, scale);
  }
}
