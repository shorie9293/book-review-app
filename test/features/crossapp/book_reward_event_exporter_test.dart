import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_event_exporter.dart';
import 'package:book_review_app/features/crossapp/domain/book_reward_event_service.dart';

Book _book() => Book(
      id: 'book-1',
      title: '坊っちゃん',
      author: '夏目漱石',
      isbn: '9784101010021',
      readingStatus: ReadingStatus.finished,
    );

Map<String, dynamic> _event({String eventId = 'evt-1'}) {
  const service = BookRewardEventService();
  return service.buildCompletionEvent(
    userId: 'user-1',
    book: _book(),
    completedCount: 2,
    eventId: eventId,
    timestamp: DateTime.utc(2026, 5, 26, 1, 2, 3),
  );
}

void main() {
  test('既定パスは rpg-task 契約と一致する', () {
    expect(
      BookRewardEventExporter.kDefaultBookReviewEventsPath,
      '/data/local/tmp/takamagahara_shared/book_review_reward_events.jsonl',
    );
  });

  group('lineWriter 注入', () {
    test('追記行が JSON として妥当で metadata.count が int', () async {
      final written = <String>[];
      final exporter = BookRewardEventExporter(
        lineWriter: (path, line) async {
          expect(path, BookRewardEventExporter.kDefaultBookReviewEventsPath);
          written.add(line);
        },
      );

      expect(await exporter.append(_event()), isTrue);
      expect(written, hasLength(1));

      final decoded = jsonDecode(written.single) as Map<String, dynamic>;
      expect(decoded['event_id'], 'evt-1');
      expect(decoded['event_type'], 'book_completed');
      expect(decoded['user_id'], 'user-1');
      expect(
        (decoded['metadata'] as Map<String, dynamic>)['count'] is int,
        isTrue,
      );
    });

    test('複数回 append で2行になる', () async {
      final written = <String>[];
      final exporter = BookRewardEventExporter(
        filePath: '/tmp/ignored.jsonl',
        lineWriter: (_, line) async => written.add(line),
      );

      expect(await exporter.append(_event(eventId: 'a')), isTrue);
      expect(await exporter.append(_event(eventId: 'b')), isTrue);
      expect(written, hasLength(2));
      expect(
        written.map((l) => jsonDecode(l)['event_id']).toList(),
        ['a', 'b'],
      );
    });

    test('書込失敗は false を返し、例外を漏らさない', () async {
      final exporter = BookRewardEventExporter(
        filePath: '/tmp/ignored.jsonl',
        lineWriter: (_, __) async => throw const FileSystemException('boom'),
      );

      expect(await exporter.append(_event()), isFalse);
    });

    test('ファイルシステム例外以外でも false', () async {
      final exporter = BookRewardEventExporter(
        lineWriter: (_, __) async => throw StateError('unexpected'),
      );
      expect(await exporter.append(_event()), isFalse);
    });
  });

  group('実ファイルへの追記', () {
    late Directory tempDir;

    setUp(
        () => tempDir = Directory.systemTemp.createTempSync('book_reward_evt'));
    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('親ディレクトリを作成して1行追記し、2回目で2行になる', () async {
      final path = '${tempDir.path}/nested/sub/events.jsonl';
      final exporter = BookRewardEventExporter(filePath: path);

      expect(await exporter.append(_event(eventId: 'e1')), isTrue);
      expect(await exporter.append(_event(eventId: 'e2')), isTrue);

      final file = File(path);
      expect(file.existsSync(), isTrue);
      final lines = await file.readAsLines();
      expect(lines, hasLength(2));
      for (final line in lines) {
        final decoded = jsonDecode(line) as Map<String, dynamic>;
        expect(decoded['event_type'], 'book_completed');
        expect(
          (decoded['metadata'] as Map<String, dynamic>)['count'] is int,
          isTrue,
        );
      }
    });

    test('書込不能パスでも false（例外を投げない）', () async {
      // ディレクトリをファイルパスとして渡す = 追記が必ず失敗する
      final exporter = BookRewardEventExporter(filePath: tempDir.path);

      expect(await exporter.append(_event()), isFalse);
      expect(tempDir.existsSync(), isTrue);
    });
  });
}
