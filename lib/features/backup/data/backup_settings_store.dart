import 'package:hive/hive.dart';

import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/features/backup/domain/backup_settings_spec.dart';

/// 設定の生値の読み書き境界。
///
/// 控えの収集・復元はこの境界越しにだけ設定へ触れる
/// （Hive 実装とインメモリ実装を差し替えられる）。
abstract interface class BackupSettingsStore {
  /// 許可リストに載る設定の現在値を読む（未保存キーは含めない）。
  Future<Map<String, Object?>> readRaw();

  /// 許可リストに載る設定だけを書く（未知キー・秘密・型不一致は捨てる）。
  Future<void> writeValues(Map<String, Object?> values);
}

/// 設定が入っている Hive ボックス名。
///
/// - `settings` … テーマ・動きを減らす（String 型）
/// - `settings_scalars` … 文字サイズ（double 型）
/// - `tutorial_settings` … チュートリアル完了（bool 型）
const String _settingsBox = 'settings';
const String _scalarsBox = 'settings_scalars';
const String _tutorialBox = 'tutorial_settings';

/// キーが入っているボックス名（未知キーは null）。
String? _boxNameForKey(String key) => switch (key) {
      'book_review_theme_mode' || 'book_reduce_motion' => _settingsBox,
      'book_review_text_scale' => _scalarsBox,
      'book_review_tutorial_completed' => _tutorialBox,
      _ => null,
    };

/// Hive 実装。1キーの失敗が他へ波及しないよう、読み書きはキー単位で握る。
class HiveBackupSettingsStore implements BackupSettingsStore {
  /// 実装を生成する。
  const HiveBackupSettingsStore();

  @override
  Future<Map<String, Object?>> readRaw() async {
    final raw = <String, Object?>{};
    for (final spec in kBackupSettingSpecs) {
      if (spec.isSecret) continue;
      final boxName = _boxNameForKey(spec.key);
      if (boxName == null) continue;
      try {
        final box = await _openBox(boxName, create: false);
        if (box == null) continue;
        final value = box.get(spec.key);
        if (value == null) continue;
        raw[spec.key] = value;
      } catch (_) {
        // 1キー読めなくても残りは載せる（設定は任意項目）。
      }
    }
    return raw;
  }

  @override
  Future<void> writeValues(Map<String, Object?> values) async {
    for (final entry in values.entries) {
      final spec = backupSettingSpecFor(entry.key);
      if (spec == null || spec.isSecret) continue;
      final boxName = _boxNameForKey(spec.key);
      if (boxName == null) continue;
      final coerced = _coerce(spec.key, entry.value);
      if (coerced == null) continue;
      try {
        final box = await _openBox(boxName, create: true);
        if (box == null) continue;
        await box.put(spec.key, coerced);
      } catch (_) {
        // 個別キーの失敗（型競合等）は握って次へ。
      }
    }
  }

  /// 値を型検証して書き込み用の型へ揃える。書いてはいけない値は null。
  Object? _coerce(String key, Object? value) {
    switch (key) {
      case 'book_review_theme_mode':
        if (value is! String) return null;
        final known = ThemeModeSetting.values.any(
          (setting) => setting.storageKey == value,
        );
        return known ? value : null;
      case 'book_reduce_motion':
        if (value is! String) return null;
        final known = ReduceMotionSetting.values.any(
          (setting) => setting.storageKey == value,
        );
        return known ? value : null;
      case 'book_review_text_scale':
        if (value is! num) return null;
        final scale = value.toDouble();
        return TextScaleSetting.isAllowed(scale) ? scale : null;
      case 'book_review_tutorial_completed':
        return value is bool ? value : null;
      default:
        return null;
    }
  }

  /// ボックスを開く。存在しないボックスは [create] が false なら開かない
  /// （読むだけで空ボックスを作らない）。
  ///
  /// Hive は「開いているボックスの型」と要求型が厳密一致しないと例外を投げる
  /// （`dynamic` でも不一致扱い）。必ず実型で開く。
  Future<Box<dynamic>?> _openBox(
    String boxName, {
    required bool create,
  }) async {
    try {
      if (!create &&
          !Hive.isBoxOpen(boxName) &&
          !await Hive.boxExists(boxName)) {
        return null;
      }
      return switch (boxName) {
        _scalarsBox => await Hive.openBox<double>(boxName),
        _tutorialBox => await Hive.openBox<bool>(boxName),
        _ => await Hive.openBox<String>(boxName),
      };
    } catch (_) {
      return null;
    }
  }
}
