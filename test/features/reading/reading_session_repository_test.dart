import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

void main() {
  group('InMemoryReadingSessionRepository', () {
    late InMemoryReadingSessionRepository repo;

    setUp(() {
      repo = InMemoryReadingSessionRepository();
    });

    ReadingSession session(
      String id, {
      DateTime? startedAt,
      int durationMinutes = 10,
    }) {
      return ReadingSession(
        id: id,
        bookId: 'b$id',
        startedAt: startedAt ?? DateTime(2026, 10, 1),
        durationMinutes: durationMinutes,
      );
    }

    test('loadAll 初期は空', () async {
      expect(await repo.loadAll(), isEmpty);
    });

    test('add → loadAll で復元', () async {
      await repo.add(session('s1'));
      await repo.add(session('s2'));
      final all = await repo.loadAll();
      expect(all.length, 2);
      expect(all.map((s) => s.id), containsAll(['s1', 's2']));
    });

    test('loadAll は startedAt 降順', () async {
      await repo.add(session('old', startedAt: DateTime(2026, 10, 1)));
      await repo.add(session('new', startedAt: DateTime(2026, 10, 3)));
      await repo.add(session('mid', startedAt: DateTime(2026, 10, 2)));
      final all = await repo.loadAll();
      expect(all.map((s) => s.id).toList(), ['new', 'mid', 'old']);
    });

    test('update で上書き', () async {
      await repo.add(session('s1', durationMinutes: 10));
      await repo.update(session('s1', durationMinutes: 90));
      final all = await repo.loadAll();
      expect(all.length, 1);
      expect(all.single.durationMinutes, 90);
    });

    test('remove で削除', () async {
      await repo.add(session('s1'));
      await repo.add(session('s2'));
      await repo.remove('s1');
      final all = await repo.loadAll();
      expect(all.length, 1);
      expect(all.single.id, 's2');
    });

    test('存在しない id の remove/update でも落ちない', () async {
      await repo.remove('nope');
      await repo.update(session('nope'));
      expect(await repo.loadAll(), isEmpty);
    });
  });

  group('HiveReadingSessionRepository', () {
    final tempDir = Directory.systemTemp.createTempSync('reading_sessions');
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

    ReadingSession session(
      String id, {
      DateTime? startedAt,
      int durationMinutes = 10,
    }) {
      return ReadingSession(
        id: id,
        bookId: 'b$id',
        startedAt: startedAt ?? DateTime(2026, 10, 1),
        durationMinutes: durationMinutes,
      );
    }

    test('boxName は reading_sessions', () {
      expect(HiveReadingSessionRepository.boxName, 'reading_sessions');
    });

    test('loadAll 初期は空', () async {
      expect(await repo.loadAll(), isEmpty);
    });

    test('add → loadAll で復元', () async {
      await repo.add(session('s1', startedAt: DateTime(2026, 10, 2, 9)));
      final all = await repo.loadAll();
      expect(all.length, 1);
      expect(all.single.id, 's1');
      expect(all.single.bookId, 'bs1');
      expect(
        all.single.startedAt,
        DateTime(2026, 10, 2, 9),
      );
      expect(all.single.durationMinutes, 10);
    });

    test('loadAll は startedAt 降順', () async {
      await repo.add(session('a', startedAt: DateTime(2026, 10, 1)));
      await repo.add(session('c', startedAt: DateTime(2026, 10, 3)));
      await repo.add(session('b', startedAt: DateTime(2026, 10, 2)));
      final all = await repo.loadAll();
      expect(all.map((s) => s.id).toList(), ['c', 'b', 'a']);
    });

    test('update で上書き', () async {
      await repo.add(session('s1'));
      await repo.update(session('s1', durationMinutes: 120));
      final all = await repo.loadAll();
      expect(all.length, 1);
      expect(all.single.durationMinutes, 120);
    });

    test('remove で削除', () async {
      await repo.add(session('s1'));
      await repo.add(session('s2'));
      await repo.remove('s1');
      final all = await repo.loadAll();
      expect(all.single.id, 's2');
    });

    test('破損JSON行は読み飛ばす', () async {
      await repo.add(session('s1'));
      final box = await Hive.openBox<String>(
        HiveReadingSessionRepository.boxName,
      );
      await box.put('broken', 'not-json');
      await box.put('bad-shape', json.encode(<String, dynamic>{}));
      final all = await repo.loadAll();
      expect(all.length, 1);
      expect(all.single.id, 's1');
    });

    test('Noop リポジトリは何もしない', () async {
      const noop = NoopReadingSessionRepository();
      expect(await noop.loadAll(), isEmpty);
      await noop.add(session('s1'));
      await noop.update(session('s1'));
      await noop.remove('s1');
      expect(await noop.loadAll(), isEmpty);
    });
  });
}
