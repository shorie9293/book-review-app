import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// クロスアプリ連携用 userId の保管庫。
///
/// Supabase を導入していない book-review-app では、端末ローカルに
/// 生成した uuid v4 を userId として使い、その先頭8文字をリンクコードとして
/// rpg-task の設定画面に手入力してもらう。
abstract class CrossAppLinkRepository {
  /// 保存済みの userId。未保存なら null。
  Future<String?> loadUserId();

  /// 保存済みの userId。無ければ uuid v4 を生成して保存し、返す。
  ///
  /// 永続化できない環境（Hive 未初期化など）では '' を返す（例外は投げない）。
  Future<String> ensureUserId();
}

/// Hive box `cross_app_link` の key `user_id` に保存する実装。
///
/// Hive 未初期化でも例外を漏らさない（loadUserId → null / ensureUserId → ''）。
/// 破損値（String 以外）も null 扱い。
class HiveCrossAppLinkRepository implements CrossAppLinkRepository {
  const HiveCrossAppLinkRepository();

  /// Hive のボックス名。
  static const String boxName = 'cross_app_link';

  /// userId を保存するキー。
  static const String userIdKey = 'user_id';

  static const Uuid _uuid = Uuid();

  @override
  Future<String?> loadUserId() async {
    final box = await _openBox();
    if (box == null) return null;
    try {
      final value = box.get(userIdKey);
      // 破損値（String 以外）・空白のみは未保存として扱う
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> ensureUserId() async {
    final existing = await loadUserId();
    if (existing != null) return existing;

    final box = await _openBox();
    if (box == null) return '';

    final generated = _uuid.v4();
    try {
      await box.put(userIdKey, generated);
    } catch (_) {
      // 保存できないなら、後で重複イベントになるため生成値は返さない
      return '';
    }
    return generated;
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
class InMemoryCrossAppLinkRepository implements CrossAppLinkRepository {
  InMemoryCrossAppLinkRepository({String? userId}) : _userId = userId;

  String? _userId;

  static const Uuid _uuid = Uuid();

  @override
  Future<String?> loadUserId() async {
    final value = _userId;
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  @override
  Future<String> ensureUserId() async {
    final existing = await loadUserId();
    if (existing != null) return existing;
    final generated = _uuid.v4();
    _userId = generated;
    return generated;
  }
}

/// 何もしない実装（連携無効時のフォールバック）。null / '' を返す。
class NoopCrossAppLinkRepository implements CrossAppLinkRepository {
  const NoopCrossAppLinkRepository();

  @override
  Future<String?> loadUserId() async => null;

  @override
  Future<String> ensureUserId() async => '';
}
