import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/domain/reading_session_service.dart';

/// 読書セッションのリポジトリ抽象。
abstract class ReadingSessionRepository {
  Future<List<ReadingSession>> loadAll();

  Future<void> add(ReadingSession session);

  Future<void> update(ReadingSession session);

  Future<void> remove(String id);
}

/// Hive を使用した [ReadingSessionRepository] の実装。
///
/// セッションは JSON 文字列として保存する（TypeAdapter 不要）。
/// ボックス名は 'reading_sessions'、キー = セッション id、値 = jsonEncode。
/// 破損レコードは読み飛ばし、他のレコードの読み取りを妨げない。
class HiveReadingSessionRepository implements ReadingSessionRepository {
  /// Hive のボックス名
  static const String boxName = 'reading_sessions';

  const HiveReadingSessionRepository();

  /// 初期化（テスト時は boxName を指定して呼び出す）。
  Future<void> init({String? boxNameOverride}) async {
    await Hive.openBox<String>(boxNameOverride ?? boxName);
  }

  /// テスト用：ボックスをクリアする。
  Future<void> clear() async {
    final box = await _open();
    await box.clear();
  }

  /// ボックスを閉じる。
  Future<void> close() async {
    final box = await _open();
    await box.close();
  }

  Future<Box<String>> _open({String? boxNameOverride}) =>
      Hive.openBox<String>(boxNameOverride ?? boxName);

  @override
  Future<List<ReadingSession>> loadAll() async {
    final box = await _open();
    final sessions = <ReadingSession>[];
    for (final raw in box.values) {
      final session = _decode(raw);
      if (session != null) sessions.add(session);
    }
    return ReadingSessionService().sortByRecent(sessions);
  }

  @override
  Future<void> add(ReadingSession session) async {
    final box = await _open();
    await box.put(session.id, json.encode(session.toJson()));
  }

  @override
  Future<void> update(ReadingSession session) async {
    final box = await _open();
    if (box.containsKey(session.id)) {
      await box.put(session.id, json.encode(session.toJson()));
    }
  }

  @override
  Future<void> remove(String id) async {
    final box = await _open();
    await box.delete(id);
  }

  ReadingSession? _decode(String raw) {
    try {
      final map = json.decode(raw);
      if (map is! Map<String, dynamic>) return null;
      return ReadingSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

/// テスト・プレビュー用のインメモリ実装。
class InMemoryReadingSessionRepository implements ReadingSessionRepository {
  final Map<String, ReadingSession> _store = {};

  /// 現在保持しているセッション件数。
  int get length => _store.length;

  @override
  Future<List<ReadingSession>> loadAll() async {
    return ReadingSessionService().sortByRecent(_store.values.toList());
  }

  @override
  Future<void> add(ReadingSession session) async {
    _store[session.id] = session;
  }

  @override
  Future<void> update(ReadingSession session) async {
    if (_store.containsKey(session.id)) {
      _store[session.id] = session;
    }
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }
}

/// 何もしない実装（プレビュー・フォールバック用）。
class NoopReadingSessionRepository implements ReadingSessionRepository {
  const NoopReadingSessionRepository();

  @override
  Future<List<ReadingSession>> loadAll() async => const [];

  @override
  Future<void> add(ReadingSession session) async {}

  @override
  Future<void> update(ReadingSession session) async {}

  @override
  Future<void> remove(String id) async {}
}
