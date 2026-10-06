import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/stats/domain/reading_stats_service.dart';

/// 親探針（合成の不変条件）。
///
/// 眷属は個別操作しか撃たないため、境界・縫ぎ目・年分離を親が独自に検証する。
void main() {
  final now = DateTime(2026, 9, 15, 12);

  Book book(
    String id, {
    String author = '著者A',
    DateTime? finishedAt,
    int? pageCount,
  }) {
    return Book(
      id: id,
      title: '本$id',
      author: author,
      isbn: '',
      pageCount: pageCount,
      readingStatus: ReadingStatus.finished,
      finishedAt: finishedAt,
    );
  }

  Review review(String id, String bookId, {DateTime? at}) {
    return Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: 'text',
      createdAt: at ?? DateTime(2026, 5, 1),
    );
  }

  test('探針1: 前年12/31当日の読了も前年に取りこぼさない', () {
    final books = [
      book('b1', finishedAt: DateTime(2025, 12, 31, 15, 30), pageCount: 100),
      book('b2', finishedAt: DateTime(2026, 1, 1), pageCount: 200),
    ];
    final cmp = ReadingStatsService.compareYears(
      books: books,
      reviews: const [],
      now: now,
    );
    expect(cmp.previous.totalFinished, 1);
    expect(cmp.previous.totalPages, 100);
    expect(cmp.current.totalFinished, 1);
    expect(cmp.current.totalPages, 200);
  });

  test('探針2: current は compute(now) の結果と一致する（縫ぎ目）', () {
    final books = [
      book('b1', finishedAt: DateTime(2026, 3, 1), pageCount: 100),
      book('b2', finishedAt: DateTime(2026, 4, 1), pageCount: 50),
      book('b3', finishedAt: DateTime(2025, 8, 1), pageCount: 999),
    ];
    final reviews = [review('r1', 'b1')];
    final cmp = ReadingStatsService.compareYears(
      books: books,
      reviews: reviews,
      now: now,
    );
    final direct = ReadingStatsService.compute(
      books: books,
      reviews: reviews,
      now: now,
    );
    expect(cmp.current.year, direct.year);
    expect(cmp.current.totalFinished, direct.totalFinished);
    expect(cmp.current.totalPages, direct.totalPages);
    expect(cmp.current.authorCount, direct.authorCount);
  });

  test('探針3: 2年前の読了はどちらの年にも集計されない（年分離）', () {
    final books = [
      book('b1', finishedAt: DateTime(2024, 6, 1), pageCount: 500),
      book('b2', finishedAt: DateTime(2026, 6, 1), pageCount: 100),
    ];
    final cmp = ReadingStatsService.compareYears(
      books: books,
      reviews: const [],
      now: now,
    );
    expect(cmp.previous.totalFinished, 0);
    expect(cmp.current.totalFinished, 1);
    expect(cmp.finishedDiff, 1);
  });
}
