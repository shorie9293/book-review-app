import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/queue/domain/reading_queue_service.dart';

Book book(String id, {ReadingStatus status = ReadingStatus.unread}) => Book(
      id: id,
      title: 'Title $id',
      author: 'Author $id',
      isbn: 'isbn-$id',
      readingStatus: status,
    );

void main() {
  final now = DateTime(2026, 9, 18, 10);
  final later = now.add(const Duration(hours: 1));
  ReadingQueueEntry entry(String bookId, int position, [DateTime? at]) =>
      ReadingQueueEntry(bookId: bookId, position: position, addedAt: at ?? now);

  group('normalize', () {
    test('position を 1..n に詰め直す', () {
      final result = ReadingQueueService.normalize(
          [entry('a', 5), entry('b', 9), entry('c', 2)]);
      expect(result.map((e) => e.position).toList(), [1, 2, 3]);
      expect(result.map((e) => e.bookId).toList(), ['c', 'a', 'b']);
    });

    test('同 position は addedAt 昇順で安定ソート', () {
      final result = ReadingQueueService
          .normalize([entry('b', 1, later), entry('a', 1, now)]);
      expect(result.map((e) => e.bookId).toList(), ['a', 'b']);
    });

    test('addedAt も同じなら bookId 昇順', () {
      final result =
          ReadingQueueService.normalize([entry('b', 1), entry('a', 1)]);
      expect(result.map((e) => e.bookId).toList(), ['a', 'b']);
    });

    test('引数のリストを変更しない', () {
      final input = [entry('a', 5), entry('b', 9)];
      ReadingQueueService.normalize(input);
      expect(input.map((e) => e.position).toList(), [5, 9]);
    });
  });

  group('enqueue', () {
    test('末尾に追加する', () {
      final result =
          ReadingQueueService.enqueue([entry('a', 1)], 'b', later);
      expect(result.map((e) => e.bookId).toList(), ['a', 'b']);
      expect(result.last.addedAt, later);
    });

    test('既に含まれるなら冪等（変更しない）', () {
      final current = [entry('a', 1), entry('b', 2)];
      final result = ReadingQueueService.enqueue(current, 'a', later);
      expect(result.map((e) => e.bookId).toList(), ['a', 'b']);
      expect(result.first.addedAt, now);
    });

    test('空文字 bookId は ArgumentError', () {
      expect(() => ReadingQueueService.enqueue([], '', now),
          throwsArgumentError);
    });

    test('空キューへの追加は position 1', () {
      final result = ReadingQueueService.enqueue([], 'a', now);
      expect(result.single.position, 1);
    });
  });

  group('dequeue', () {
    test('除去して normalize する', () {
      final current = [entry('a', 1), entry('b', 2), entry('c', 3)];
      final result = ReadingQueueService.dequeue(current, 'b');
      expect(result.map((e) => e.bookId).toList(), ['a', 'c']);
      expect(result.map((e) => e.position).toList(), [1, 2]);
    });

    test('存在しない bookId は変更なし', () {
      final current = [entry('a', 1)];
      final result = ReadingQueueService.dequeue(current, 'zzz');
      expect(result.single.bookId, 'a');
    });
  });

  group('moveUp / moveDown / moveTo', () {
    final current = [entry('a', 1), entry('b', 2), entry('c', 3)];

    test('moveUp で b が先頭になる', () {
      final result = ReadingQueueService.moveUp(current, 'b');
      expect(result.map((e) => e.bookId).toList(), ['b', 'a', 'c']);
      expect(result.map((e) => e.position).toList(), [1, 2, 3]);
    });

    test('moveUp 先頭では何もしない', () {
      expect(ReadingQueueService.moveUp(current, 'a')
          .map((e) => e.bookId)
          .toList(), ['a', 'b', 'c']);
    });

    test('moveDown で b が末尾になる', () {
      final result = ReadingQueueService.moveDown(current, 'b');
      expect(result.map((e) => e.bookId).toList(), ['a', 'c', 'b']);
    });

    test('moveDown 末尾では何もしない', () {
      expect(ReadingQueueService.moveDown(current, 'c')
          .map((e) => e.bookId)
          .toList(), ['a', 'b', 'c']);
    });

    test('moveTo で b を index 0 へ', () {
      final result = ReadingQueueService.moveTo(current, 'b', 0);
      expect(result.map((e) => e.bookId).toList(), ['b', 'a', 'c']);
    });

    test('moveTo 範囲外では何もしない（例外を投げない）', () {
      expect(ReadingQueueService.moveTo(current, 'b', 99)
          .map((e) => e.bookId)
          .toList(), ['a', 'b', 'c']);
      expect(ReadingQueueService.moveTo(current, 'b', -1)
          .map((e) => e.bookId)
          .toList(), ['a', 'b', 'c']);
    });

    test('存在しない bookId は normalize した結果を返す', () {
      final messy = [entry('x', 5), entry('y', 9)];
      final result = ReadingQueueService.moveUp(messy, 'zzz');
      expect(result.map((e) => e.position).toList(), [1, 2]);
    });
  });

  group('resolveQueue / nextToRead', () {
    final books = [
      book('a'),
      book('b', status: ReadingStatus.reading),
      book('c', status: ReadingStatus.finished),
    ];
    final entries = [entry('a', 1), entry('c', 2), entry('b', 3)];

    test('キュー順を保ち、読了を除外する', () {
      final result = ReadingQueueService.resolveQueue(entries, books);
      expect(result.map((b) => b.id).toList(), ['a', 'b']);
    });

    test('books に存在しない bookId を除外する', () {
      final withUnknown = [entry('zzz', 1), entry('a', 2)];
      final result = ReadingQueueService.resolveQueue(withUnknown, books);
      expect(result.map((b) => b.id).toList(), ['a']);
    });

    test('nextToRead は先頭の1冊', () {
      expect(ReadingQueueService.nextToRead(entries, books)?.id, 'a');
    });

    test('空キューなら nextToRead は null', () {
      expect(ReadingQueueService.nextToRead([], books), isNull);
    });

    test('全員読了なら nextToRead は null', () {
      final finishedOnly = [entry('c', 1)];
      expect(ReadingQueueService.nextToRead(finishedOnly, books), isNull);
    });

    test('resolveQueue は非破壊', () {
      final input = List<ReadingQueueEntry>.of(entries);
      ReadingQueueService.resolveQueue(input, books);
      expect(input, entries);
    });
  });
}
