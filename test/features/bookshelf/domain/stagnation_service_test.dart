import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/stagnation.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book({
  required String id,
  String title = '本',
  String author = '著者',
  ReadingStatus status = ReadingStatus.unread,
  int currentPage = 0,
  DateTime? addedAt,
  int? pageCount,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    isbn: 'isbn-$id',
    readingStatus: status,
    currentPage: currentPage,
    addedAt: addedAt,
    pageCount: pageCount,
  );
}

final _now = DateTime(2026, 10, 3, 12);

void main() {
  group('StagnationService.daysStalledFor', () {
    test('addedAt からの経過日数を返す', () {
      final book = _book(id: 'b1', addedAt: DateTime(2026, 9, 1));
      expect(StagnationService.daysStalledFor(book, now: _now), 32);
    });

    test('addedAt が未来なら 0 にクランプする', () {
      final book = _book(id: 'b2', addedAt: DateTime(2026, 10, 10));
      expect(StagnationService.daysStalledFor(book, now: _now), 0);
    });
  });

  group('StagnationService.detect', () {
    test('読了以外で minDays 以上経過した本のみ抽出する', () {
      final books = [
        _book(id: 'old-unread', addedAt: _now.subtract(const Duration(days: 30))),
        _book(id: 'fresh', addedAt: _now.subtract(const Duration(days: 3))),
        _book(
          id: 'finished',
          status: ReadingStatus.finished,
          addedAt: _now.subtract(const Duration(days: 100)),
        ),
      ];
      final entries = StagnationService.detect(books, now: _now);
      expect(entries.map((e) => e.book.id), ['old-unread']);
    });

    test('addedAt が null の本は判定対象外', () {
      final books = [_book(id: 'no-date')];
      expect(StagnationService.detect(books, now: _now), isEmpty);
    });

    test('停滞理由を状態と進捗で分類する', () {
      final books = [
        _book(id: 'unread', addedAt: _now.subtract(const Duration(days: 20))),
        _book(
          id: 'no-progress',
          status: ReadingStatus.reading,
          currentPage: 0,
          addedAt: _now.subtract(const Duration(days: 20)),
        ),
        _book(
          id: 'slow',
          status: ReadingStatus.reading,
          currentPage: 12,
          addedAt: _now.subtract(const Duration(days: 20)),
        ),
      ];
      final entries = StagnationService.detect(books, now: _now);
      final byId = {for (final e in entries) e.book.id: e};
      expect(byId['unread']!.reason, StagnationReason.neverStarted);
      expect(byId['no-progress']!.reason, StagnationReason.noPageProgress);
      expect(byId['slow']!.reason, StagnationReason.longReading);
      expect(byId['unread']!.reason.label, '積読（未着手）');
      expect(byId['no-progress']!.reason.label, '読書中だが進捗なし');
      expect(byId['slow']!.reason.label, '読書中（長期経過）');
    });

    test('minDays を指定して閾値を変えられる', () {
      final books = [_book(id: 'w7', addedAt: _now.subtract(const Duration(days: 8)))];
      expect(StagnationService.detect(books, now: _now, minDays: 7), isNotEmpty);
      expect(StagnationService.detect(books, now: _now, minDays: 14), isEmpty);
    });

    test('日数が負のエントリは生成できない', () {
      expect(
        () => StagnationEntry(
          book: _book(id: 'x'),
          daysStalled: -1,
          reason: StagnationReason.neverStarted,
        ),
        throwsArgumentError,
      );
    });
  });

  group('StagnationService.sortByDays', () {
    test('停滞日数の降順・同値は title 昇順・入力非破壊', () {
      final a = _book(id: 'a', title: 'あ', addedAt: _now.subtract(const Duration(days: 10)));
      final b = _book(id: 'b', title: 'い', addedAt: _now.subtract(const Duration(days: 30)));
      final c = _book(id: 'c', title: 'う', addedAt: _now.subtract(const Duration(days: 10)));
      final entries = StagnationService.detect([a, b, c], now: _now, minDays: 7);
      final sorted = StagnationService.sortByDays(entries);
      expect(sorted.map((e) => e.book.id), ['b', 'a', 'c']);
      expect(entries.map((e) => e.book.id).toSet(), {'a', 'b', 'c'});
    });
  });

  group('StagnationService.filterByReason', () {
    test('null は全件・指定理由のみ絞り込み', () {
      final books = [
        _book(id: 'u', addedAt: _now.subtract(const Duration(days: 20))),
        _book(
          id: 'r',
          status: ReadingStatus.reading,
          currentPage: 5,
          addedAt: _now.subtract(const Duration(days: 20)),
        ),
      ];
      final entries = StagnationService.detect(books, now: _now);
      expect(StagnationService.filterByReason(entries, null).length, 2);
      expect(
        StagnationService.filterByReason(entries, StagnationReason.neverStarted).map((e) => e.book.id),
        ['u'],
      );
    });
  });

  group('StagnationService.searchByText', () {
    test('title か author の部分一致（正規化比較）', () {
      final books = [
        _book(id: 'd1', title: 'ドラゴン教本', author: '山田', addedAt: _now.subtract(const Duration(days: 20))),
        _book(id: 'd2', title: '猫の飼い方', author: '鈴木龍一', addedAt: _now.subtract(const Duration(days: 20))),
      ];
      final entries = StagnationService.detect(books, now: _now);
      expect(
        StagnationService.searchByText(entries, 'ドラゴン').map((e) => e.book.id),
        ['d1'],
      );
      expect(
        StagnationService.searchByText(entries, '龍一').map((e) => e.book.id),
        ['d2'],
      );
      expect(StagnationService.searchByText(entries, '　').length, 2);
    });
  });

  group('StagnationService.countsByReason', () {
    test('理由別件数を数える', () {
      final books = [
        _book(id: 'u1', addedAt: _now.subtract(const Duration(days: 20))),
        _book(id: 'u2', addedAt: _now.subtract(const Duration(days: 25))),
        _book(
          id: 'r1',
          status: ReadingStatus.reading,
          currentPage: 3,
          addedAt: _now.subtract(const Duration(days: 20)),
        ),
      ];
      final counts = StagnationService.countsByReason(StagnationService.detect(books, now: _now));
      expect(counts[StagnationReason.neverStarted], 2);
      expect(counts[StagnationReason.longReading], 1);
      expect(counts[StagnationReason.noPageProgress] ?? 0, 0);
    });
  });
}