import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/crash/crash_log_entry.dart';
import 'package:book_review_app/core/crash/crash_log_repository.dart';
import 'package:book_review_app/core/crash/crash_log_service.dart';

void main() {
  late Directory tempDir;

  File logFile() => File('${tempDir.path}/${FileCrashLogRepository.fileName}');

  FileCrashLogRepository newRepository() =>
      FileCrashLogRepository(directoryProvider: () async => tempDir);

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crash_log_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  CrashLogEntry entry(int i, {DateTime? at}) => CrashLogEntry(
        timestamp: at ?? DateTime.utc(2026, 1, 1, 0, 0, i % 60),
        kind: 'zone',
        message: 'e$i',
      );

  group('FileCrashLogRepository', () {
    test('record を1回呼ぶと1行増える', () async {
      final repo = newRepository();
      final logger = CrashLogger(repo);

      logger.record(StateError('boom'), StackTrace.fromString('#0 a'),
          kind: 'zone');
      // record は投げっぱなし。書き込み完了まで少し待つ。
      for (var i = 0; i < 200 && !logFile().existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      for (var i = 0; i < 50; i++) {
        if (logFile().existsSync() &&
            logFile().readAsStringSync().trim().isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final lines = logFile()
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 1);
      final decoded = CrashLogEntry.fromJson(
          jsonDecode(lines.first) as Map<String, dynamic>);
      expect(decoded!.message, 'Bad state: boom');
      expect(decoded.kind, 'zone');
      expect(decoded.stackTop, '#0 a');
    });

    test('51件目で最古が落ち、50件だけ残る', () async {
      final repo = newRepository();
      for (var i = 0; i < 51; i++) {
        await repo.append(entry(i));
      }

      final loaded = await repo.loadAll();
      expect(loaded.length, 50);
      expect(loaded.first.message, 'e1');
      expect(loaded.last.message, 'e50');
      expect(
          logFile().readAsLinesSync().where((l) => l.trim().isNotEmpty).length,
          50);
    });

    test('壊れた行は読み飛ばす', () async {
      final repo = newRepository();
      await repo.append(entry(0));
      logFile().writeAsStringSync(
        '${logFile().readAsStringSync()}'
        'this is not json\n'
        '{"ts":123,"kind":"zone","message":"x"}\n'
        '{"ts":"2026-01-02T00:00:00.000Z","kind":"flutter","message":"ok"}\n',
      );

      final loaded = await repo.loadAll();
      expect(loaded.length, 2);
      expect(loaded.last.message, 'ok');
    });

    test('ファイルが無ければ空（例外を投げない）', () async {
      expect(await newRepository().loadAll(), isEmpty);
    });

    test('clear でログが消える', () async {
      final repo = newRepository();
      await repo.append(entry(0));
      await repo.clear();
      expect(await repo.loadAll(), isEmpty);
    });

    test('ディレクトリ解決に失敗しても握りつぶす', () async {
      final repo = FileCrashLogRepository(
        directoryProvider: () async => throw const FileSystemException('no'),
      );
      await expectLater(repo.append(entry(0)), completes);
      expect(await repo.loadAll(), isEmpty);
    });
  });

  group('InMemoryCrashLogRepository', () {
    test('append / clear / 50件ローテート', () async {
      final repo = InMemoryCrashLogRepository();
      for (var i = 0; i < 51; i++) {
        await repo.append(entry(i));
      }
      expect(repo.length, 50);
      final loaded = await repo.loadAll();
      expect(loaded.first.message, 'e1');
      await repo.clear();
      expect(await repo.loadAll(), isEmpty);
    });
  });
}
