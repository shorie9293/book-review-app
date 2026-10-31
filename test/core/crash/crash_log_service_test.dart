import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/crash/crash_log_entry.dart';
import 'package:book_review_app/core/crash/crash_log_repository.dart';
import 'package:book_review_app/core/crash/crash_log_service.dart';

void main() {
  CrashLogEntry entry(DateTime at, String message) => CrashLogEntry(
        timestamp: at,
        kind: 'zone',
        message: message,
      );

  group('summarize', () {
    test('0件なら null', () {
      expect(summarize(const <CrashLogEntry>[]), isNull);
    });

    test('2件なら「前回の異常終了 2件（最終 HH:mm）」', () {
      final entries = [
        entry(DateTime(2026, 1, 2, 8, 5), 'a'),
        entry(DateTime(2026, 1, 2, 9, 7), 'b'),
      ];

      expect(summarize(entries), '前回の異常終了 2件（最終 09:07）');
    });

    test('最終時刻は最新エントリ基準（並び順に依存しない）', () {
      final entries = [
        entry(DateTime(2026, 1, 2, 23, 59), 'late'),
        entry(DateTime(2026, 1, 2, 0, 1), 'early'),
      ];

      expect(summarize(entries), contains('23:59'));
    });
  });

  group('recent', () {
    test('新しい順に limit 件へ絞る', () {
      final entries = List<CrashLogEntry>.generate(
        5,
        (i) => entry(DateTime(2026, 1, 1, 0, 0, i), 'e$i'),
      );

      final result = recent(entries, limit: 3);

      expect(result.length, 3);
      expect(result.map((e) => e.message).toList(), ['e4', 'e3', 'e2']);
    });

    test('件数が limit 以下なら全件（新しい順）', () {
      final entries = [
        entry(DateTime(2026, 1, 1, 0, 0, 1), 'old'),
        entry(DateTime(2026, 1, 1, 0, 0, 2), 'new'),
      ];
      expect(recent(entries, limit: 10).first.message, 'new');
    });
  });

  group('CrashLogger', () {
    test('record は投げっぱなしで追記し、例外時も落ちない', () async {
      final repo = InMemoryCrashLogRepository();
      final logger = CrashLogger(repo, clock: () => DateTime(2026, 1, 1, 12));

      logger.record(StateError('boom'), StackTrace.fromString('#0 a'),
          kind: 'zone');
      await Future<void>.delayed(Duration.zero);

      final entries = await repo.loadAll();
      expect(entries.length, 1);
      expect(entries.single.kind, 'zone');
      expect(entries.single.stackTop, '#0 a');
      expect(entries.single.timestamp, DateTime(2026, 1, 1, 12));
    });

    test('保存先が例外を投げても record は例外を漏らさない', () async {
      final logger = CrashLogger(_ThrowingRepository());

      expect(() => logger.record('boom', null), returnsNormally);
      await Future<void>.delayed(Duration.zero);
    });
  });
}

class _ThrowingRepository implements CrashLogRepository {
  @override
  Future<void> append(CrashLogEntry entry) async => throw StateError('write');

  @override
  Future<void> clear() async => throw StateError('clear');

  @override
  Future<List<CrashLogEntry>> loadAll() async => throw StateError('read');
}
