import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:book_review_app/core/state/load_state.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/domain/reading_session_service.dart';

/// 読書セッションのリポジトリ抽象。
abstract class ReadingSessionRepository {
  Future<List<ReadingSession>> loadAll();

  Future<void> add(ReadingSession session);

  Future<void> update(ReadingSession session);

  Future<void> remove(String id);
}

/// 例外を投げずに [LoadResult] を返せるリポジトリが実装する任意の能力。
///
/// 既定の [ReadingSessionRepositoryLoad.tryLoadSessions] は [loadAll] の
/// 例外のみを failure 化するが、破損レコードを検知できる実装はこちらで
/// 上書きする。
abstract class ReadingSessionLoadResultSource {
  Future<LoadResult<List<ReadingSession>>> tryLoadSessions();
}

/// 既存の [ReadingSessionRepository] を壊さずに結果型 API を足す拡張。
extension ReadingSessionRepositoryLoad on ReadingSessionRepository {
  /// 読み込みを実行し、例外・破損を failure として返す。
  ///
  /// [LoadResult.failure] の message は UI にそのまま出せる日本語。
  Future<LoadResult<List<ReadingSession>>> tryLoadSessions() async {
    final self = this;
    if (self is ReadingSessionLoadResultSource) {
      return (self as ReadingSessionLoadResultSource).tryLoadSessions();
    }
    try {
      return LoadResult<List<ReadingSession>>.success(await loadAll());
    } catch (error) {
      return LoadResult<List<ReadingSession>>.failure(
        '読書セッションの読み込みに失敗しました',
        cause: error,
      );
    }
  }
}

/// Hive を使用した [ReadingSessionRepository] の実装。
///
/// セッションは JSON 文字列として保存する（TypeAdapter 不要）。
/// ボックス名は 'reading_sessions'、キー = セッション id、値 = jsonEncode。
/// 破損レコードは読み飛ばし、他のレコードの読み取りを妨げない。
class HiveReadingSessionRepository
    implements ReadingSessionRepository, ReadingSessionLoadResultSource {
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

  /// 破損・例外を握り潰さず [LoadResult] で返す。
  ///
  /// 1件でも復元できないレコードがあれば failure（再試行不能）とし、
  /// 部分的な一覧を成功として返さない。
  @override
  Future<LoadResult<List<ReadingSession>>> tryLoadSessions() async {
    try {
      final box = await _open();
      final sessions = <ReadingSession>[];
      for (final raw in box.values) {
        final session = _decode(raw);
        if (session == null) {
          return LoadResult<List<ReadingSession>>.failure(
            '保存された読書記録の一部が壊れています',
            retryable: false,
            cause: FormatException('読書セッションを復元できませんでした'),
          );
        }
        sessions.add(session);
      }
      return LoadResult<List<ReadingSession>>.success(
        ReadingSessionService().sortByRecent(sessions),
      );
    } catch (error) {
      return LoadResult<List<ReadingSession>>.failure(
        '読書セッションの読み込みに失敗しました',
        cause: error,
      );
    }
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
