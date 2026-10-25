import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/crossapp/domain/book_reward_event_service.dart';

Book _book({
  String id = 'book-1',
  String title = '吾輩は猫である',
  ReadingStatus status = ReadingStatus.unread,
  DateTime? finishedAt,
}) {
  return Book(
    id: id,
    title: title,
    author: '夏目漱石',
    isbn: '9784101010014',
    readingStatus: status,
    finishedAt: finishedAt,
  );
}

void main() {
  const service = BookRewardEventService();

  group('shouldExport', () {
    test('unread → finished は書き出す', () {
      expect(
        service.shouldExport(
          previous: _book(),
          updated: _book(status: ReadingStatus.finished),
        ),
        isTrue,
      );
    });

    test('reading → finished は書き出す', () {
      expect(
        service.shouldExport(
          previous: _book(status: ReadingStatus.reading),
          updated: _book(status: ReadingStatus.finished),
        ),
        isTrue,
      );
    });

    test('finished → finished は再送しない', () {
      expect(
        service.shouldExport(
          previous: _book(status: ReadingStatus.finished),
          updated: _book(status: ReadingStatus.finished),
        ),
        isFalse,
      );
    });

    test('finished → reading は書き出さない', () {
      expect(
        service.shouldExport(
          previous: _book(status: ReadingStatus.finished),
          updated: _book(status: ReadingStatus.reading),
        ),
        isFalse,
      );
    });

    test('unread → reading も書き出さない', () {
      expect(
        service.shouldExport(
          previous: _book(),
          updated: _book(status: ReadingStatus.reading),
        ),
        isFalse,
      );
    });
  });

  group('completedCountOf', () {
    test('読了状態の冊数のみ数える', () {
      final books = [
        _book(id: 'a', status: ReadingStatus.finished),
        _book(id: 'b', status: ReadingStatus.reading),
        _book(id: 'c', status: ReadingStatus.unread),
        _book(id: 'd', status: ReadingStatus.finished),
      ];
      expect(service.completedCountOf(books), 2);
    });

    test('空なら0', () {
      expect(service.completedCountOf(const <Book>[]), 0);
    });

    test('重複 id でも件数どおり数える（呼び出し側の集合を尊重）', () {
      final same = _book(status: ReadingStatus.finished);
      expect(service.completedCountOf([same, same]), 2);
    });
  });

  group('buildCompletionEvent', () {
    final timestamp = DateTime.utc(2026, 5, 26, 12, 34, 56);

    test('契約どおりのキーを返す', () {
      final event = service.buildCompletionEvent(
        userId: '3f2a9c1b7d4e4a119b02abcdefabcdef',
        book: _book(
          id: 'book-42',
          title: 'こころ',
          status: ReadingStatus.finished,
          finishedAt: timestamp,
        ),
        completedCount: 7,
        eventId: 'evt-1',
        timestamp: timestamp,
      );

      expect(event['event_id'], 'evt-1');
      expect(event['event_type'], 'book_completed');
      expect(
        event['user_id'],
        '3f2a9c1b7d4e4a119b02abcdefabcdef',
      );
      expect(event['timestamp'], timestamp.toIso8601String());

      final metadata = event['metadata'] as Map<String, dynamic>;
      expect(metadata['count'], 7);
      expect(metadata['book_id'], 'book-42');
      expect(metadata['book_title'], 'こころ');
    });

    test('metadata.count は int（rpg 側が as int? で読む）', () {
      final event = service.buildCompletionEvent(
        userId: 'user-1',
        book: _book(status: ReadingStatus.finished),
        completedCount: 3,
        eventId: 'evt-2',
        timestamp: timestamp,
      );
      final metadata = event['metadata'] as Map<String, dynamic>;
      expect(metadata['count'] is int, isTrue);
      expect(metadata['count'], equals(3));
    });

    test('timestamp は UTC ISO8601 に正規化される', () {
      final jst = DateTime.parse('2026-05-26T21:34:56+09:00');
      final event = service.buildCompletionEvent(
        userId: 'user-1',
        book: _book(status: ReadingStatus.finished),
        completedCount: 1,
        eventId: 'evt-3',
        timestamp: jst,
      );
      final raw = event['timestamp'] as String;
      expect(raw.endsWith('Z'), isTrue);
      expect(DateTime.parse(raw).isAtSameMomentAs(jst), isTrue);
    });

    test('JSON エンコード可能（JSONL 1行として成立する）', () {
      final event = service.buildCompletionEvent(
        userId: 'user-1',
        book: _book(status: ReadingStatus.finished),
        completedCount: 1,
        eventId: 'evt-4',
        timestamp: timestamp,
      );
      final line = jsonEncode(event);
      final decoded = jsonDecode(line) as Map<String, dynamic>;
      expect(decoded['event_type'], 'book_completed');
      expect(
        (decoded['metadata'] as Map<String, dynamic>)['count'] is int,
        isTrue,
      );
    });

    test('userId が空/空白のみなら ArgumentError', () {
      expect(
        () => service.buildCompletionEvent(
          userId: '',
          book: _book(status: ReadingStatus.finished),
          completedCount: 1,
          eventId: 'evt-5',
          timestamp: timestamp,
        ),
        throwsArgumentError,
      );
      expect(
        () => service.buildCompletionEvent(
          userId: '   ',
          book: _book(status: ReadingStatus.finished),
          completedCount: 1,
          eventId: 'evt-6',
          timestamp: timestamp,
        ),
        throwsArgumentError,
      );
    });

    test('completedCount が負なら ArgumentError', () {
      expect(
        () => service.buildCompletionEvent(
          userId: 'user-1',
          book: _book(status: ReadingStatus.finished),
          completedCount: -1,
          eventId: 'evt-7',
          timestamp: timestamp,
        ),
        throwsArgumentError,
      );
    });
  });

  group('sentKeyOf', () {
    test('finishedAt を含む冪等キー', () {
      final finishedAt = DateTime.parse('2026-01-02T03:04:05.000Z');
      expect(
        service.sentKeyOf(
          _book(
              id: 'b1', status: ReadingStatus.finished, finishedAt: finishedAt),
        ),
        'b1|2026-01-02T03:04:05.000Z',
      );
    });

    test('finishedAt が null なら末尾は空', () {
      expect(service.sentKeyOf(_book(id: 'b1')), 'b1|');
    });
  });
}
