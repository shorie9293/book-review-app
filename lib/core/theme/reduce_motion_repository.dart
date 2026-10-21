import 'package:hive/hive.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';

/// 「動きを減らす」設定のリポジトリ
///
/// Hive の settings ボックスに選択値を保存・復元する
/// （本アプリの永続化は Hive が標準）。
class ReduceMotionRepository {
  static const String _boxName = 'settings';
  static const String _key = 'book_reduce_motion';

  const ReduceMotionRepository();

  /// 保存された設定を読み込む。未保存 / 不正値は null。
  Future<ReduceMotionSetting?> load() async {
    final box = await Hive.openBox<String>(_boxName);
    final saved = box.get(_key);
    if (saved == null) return null;
    for (final setting in ReduceMotionSetting.values) {
      if (setting.storageKey == saved) return setting;
    }
    return null;
  }

  /// 設定を保存する。
  Future<void> save(ReduceMotionSetting setting) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_key, setting.storageKey);
  }
}

/// 試練用のインメモリ実装（Hive 未初期化でも安全）。
class InMemoryReduceMotionRepository implements ReduceMotionRepository {
  /// 最後に保存された値（未保存は null）。
  ReduceMotionSetting? saved;

  /// save が呼ばれた回数。
  int saveCount = 0;

  @override
  Future<ReduceMotionSetting?> load() async => saved;

  @override
  Future<void> save(ReduceMotionSetting setting) async {
    saved = setting;
    saveCount++;
  }
}
