import 'package:hive/hive.dart';

/// 書き出し済みイベントの冪等キー保管庫。
///
/// キーは `BookRewardEventService.sentKeyOf` が返す
/// `'<book.id>|<finishedAt>'`。同じ読了を二度書き出さないために使う。
abstract class RewardExportLogRepository {
  /// 書き出し済みキーの集合。破損・未初期化時は空集合。
  Future<Set<String>> loadSentKeys();

  /// キーを記録する。冪等（既にあれば何もしない）。
  Future<void> markSent(String key);
}

/// Hive box `cross_app_reward_log` の key `sent_keys` に `List<String>` で保存する実装。
///
/// Hive 未初期化・破損時は空集合へ降格し、例外を外へ漏らさない。
class HiveRewardExportLogRepository implements RewardExportLogRepository {
  const HiveRewardExportLogRepository();

  /// Hive のボックス名。
  static const String boxName = 'cross_app_reward_log';

  /// キー一覧を保存するキー。
  static const String sentKeysKey = 'sent_keys';

  @override
  Future<Set<String>> loadSentKeys() async {
    final box = await _openBox();
    if (box == null) return <String>{};
    try {
      final raw = box.get(sentKeysKey);
      if (raw is! List) return <String>{};
      // 破損要素（非文字列）は読み飛ばす
      return <String>{
        for (final value in raw)
          if (value is String && value.isNotEmpty) value,
      };
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<void> markSent(String key) async {
    final box = await _openBox();
    if (box == null) return;
    try {
      final keys = await loadSentKeys();
      if (!keys.add(key)) return;
      await box.put(sentKeysKey, keys.toList(growable: false));
    } catch (_) {
      // best-effort: 記録できなくてもアプリを落とさない
    }
  }

  /// ボックスを開く。開けなければ null（Hive 未初期化・IO 失敗など）。
  Future<Box<dynamic>?> _openBox() async {
    try {
      if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
      return await Hive.openBox<dynamic>(boxName);
    } catch (_) {
      return null;
    }
  }
}

/// テスト・プレビュー用のインメモリ実装。
class InMemoryRewardExportLogRepository implements RewardExportLogRepository {
  InMemoryRewardExportLogRepository();

  final Set<String> _sentKeys = <String>{};

  @override
  Future<Set<String>> loadSentKeys() async => Set<String>.of(_sentKeys);

  @override
  Future<void> markSent(String key) async {
    _sentKeys.add(key);
  }
}
