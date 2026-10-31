import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

/// loadAll が例外を投げるリポジトリ。
class _ThrowingSessionRepository implements ReadingSessionRepository {
  @override
  Future<List<ReadingSession>> loadAll() async =>
      throw const FileSystemException('box が読めない');

  @override
  Future<void> add(ReadingSession session) async {}

  @override
  Future<void> update(ReadingSession session) async {}

  @override
  Future<void> remove(String id) async {}
}

ReadingSession _session(String id) => ReadingSession(
      id: id,
      startedAt: DateTime(2026, 10, 1),
      durationMinutes: 10,
    );

void main() {
  group('tryLoadSessions（拡張）', () {
    test('成功時は success でセッションを返す', () async {
      final repo = InMemoryReadingSessionRepository();
      await repo.add(_session('s1'));

      final result = await repo.tryLoadSessions();

      expect(result.isSuccess, isTrue);
      expect(result.message, isNull);
      expect(result.valueOrNull!.single.id, 's1');
    });

    test('0件は success のまま（failure ではない）', () async {
      final result =
          await const NoopReadingSessionRepository().tryLoadSessions();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('loadAll の例外は failure に変換し、cause を保持する', () async {
      final result = await _ThrowingSessionRepository().tryLoadSessions();

      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.retryable, isTrue);
      expect(result.message, '読書セッションの読み込みに失敗しました');
      expect(result.cause, isA<FileSystemException>());
    });
  });

  group('HiveReadingSessionRepository.tryLoadSessions', () {
    final tempDir = Directory.systemTemp.createTempSync('try_load_sessions');
    late HiveReadingSessionRepository repo;

    setUp(() async {
      Hive.init(tempDir.path);
      repo = const HiveReadingSessionRepository();
      await repo.init();
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('reading_sessions');
      await Hive.close();
    });

    test('正常なレコードは success', () async {
      await repo.add(_session('s1'));
      await repo.add(_session('s2'));

      final result = await repo.tryLoadSessions();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.map((s) => s.id), containsAll(['s1', 's2']));
    });

    test('破損レコードは握り潰さず failure（再試行不能）', () async {
      await repo.add(_session('s1'));
      final box = await Hive.openBox<String>(
        HiveReadingSessionRepository.boxName,
      );
      await box.put('broken', 'not-json');
      await box.put('bad-shape', json.encode(<String, dynamic>{}));

      final result = await repo.tryLoadSessions();

      expect(result.isFailure, isTrue);
      expect(result.retryable, isFalse);
      expect(result.message, '保存された読書記録の一部が壊れています');
      expect(result.cause, isA<FormatException>());
      // 部分的な一覧を成功として返していない
      expect(result.valueOrNull, isNull);
    });

    test('loadAll は従来どおり破損行を読み飛ばす（後方互換）', () async {
      await repo.add(_session('s1'));
      final box = await Hive.openBox<String>(
        HiveReadingSessionRepository.boxName,
      );
      await box.put('broken', 'not-json');

      final all = await repo.loadAll();

      expect(all.length, 1);
      expect(all.single.id, 's1');
    });
  });
}
