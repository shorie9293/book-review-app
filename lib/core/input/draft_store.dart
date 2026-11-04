import 'dart:convert';

import 'package:hive/hive.dart';

/// 下書き用の箱を開く関数の型（差し替え可能）。
typedef BoxOpener = Future<Box<String>> Function(String name);

/// 入力途中の下書きを保存する抽象。
///
/// 「保存に成功するまで下書きを消さない」を成立させるため、
/// 画面は保存成功後にのみ [clear] を呼ぶ。
abstract class DraftStore {
  /// 下書きを読む（無ければ null）。
  Future<String?> read(String key);

  /// 下書きを書く（空文字・空白のみは削除と同じ扱い）。
  Future<void> write(String key, String value);

  /// 下書きを消す。
  Future<void> clear(String key);
}

/// テスト・一時利用向けのメモリ実装。
class InMemoryDraftStore implements DraftStore {
  final Map<String, String> _drafts = {};

  /// 保存済みの下書き（検証用の読み取り専用ビュー）。
  Map<String, String> get drafts => Map.unmodifiable(_drafts);

  @override
  Future<String?> read(String key) async => _drafts[key];

  @override
  Future<void> write(String key, String value) async {
    if (value.trim().isEmpty) {
      _drafts.remove(key);
      return;
    }
    _drafts[key] = value;
  }

  @override
  Future<void> clear(String key) async {
    _drafts.remove(key);
  }
}

/// Hive による下書き保存（端末ローカル・JSON文字列）。
///
/// 下書きは「入力消失を防ぐ最後の砦」ゆえ、Hive 未初期化や I/O 失敗でも
/// 例外を投げずに黙って諦める（本編の操作を止めない）。
class HiveDraftStore implements DraftStore {
  HiveDraftStore({this.boxName = defaultBoxName, BoxOpener? opener})
      : _opener = opener;

  /// 既定のボックス名。
  static const String defaultBoxName = 'input_drafts';

  /// 箱を開く関数（試験で I/O 失敗を注入するための差し替え口）。
  final BoxOpener? _opener;

  final String boxName;
  Box<String>? _box;

  /// 実際に箱を開く。
  Future<Box<String>> _defaultOpen(String name) => Hive.openBox<String>(name);

  Future<Box<String>?> _open() async {
    if (_box?.isOpen ?? false) return _box;
    try {
      final opener = _opener;
      if (opener != null) {
        _box = await opener(boxName);
      } else {
        // Hive 未初期化のまま openBox を呼ぶと、Hive 内部が未処理の Future エラーを
        // ゾーンへ流し、アプリや試練を汚染する（openBox はエラーを completer に
        // 流したまま待たない）。先に初期化済みかを確かめ、未初期化なら諦める。
        await Hive.boxExists(boxName);
        _box = await _defaultOpen(boxName);
      }
      return _box;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> read(String key) async {
    final box = await _open();
    if (box == null) return null;
    try {
      return box.get(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final box = await _open();
    if (box == null) return;
    try {
      if (value.trim().isEmpty) {
        await box.delete(key);
      } else {
        await box.put(key, value);
      }
    } catch (_) {
      // 下書き保存の失敗で本編を止めない。
    }
  }

  @override
  Future<void> clear(String key) async {
    final box = await _open();
    if (box == null) return;
    try {
      await box.delete(key);
    } catch (_) {
      // 同上。
    }
  }
}

/// 下書きの JSON を安全に復元する（破損・旧形式は null）。
Map<String, dynamic>? decodeDraftJson(String raw) {
  try {
    final decoded = json.decode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return null;
  } catch (_) {
    return null;
  }
}
