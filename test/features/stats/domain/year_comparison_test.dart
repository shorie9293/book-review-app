import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/stats/domain/reading_stats_service.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12);

  Book book(
    String id, {
    String author = '著者A',
    ReadingStatus status = ReadingStatus.unread,
    DateTime? finishedAt,
    int? pageCount,
  }) {
    return Book(
      id: id,
      title: '本$id',
      author: author,
      isbn: '',
      pageCount: pageCount,
      readingStatus: status,
      finishedAt: finishedAt,
    );
  }

  Review review(String id, String bookId, {int rating = 4, DateTime? at}) {
    return Review(
      id: id,
      bookId: bookId,
      rating: rating,
      text: 'text',
      createdAt: at ?? DateTime(2026, 5, 1),
    );
  }

  group('ReadingStats.totalPages / authorCount', () {
    test('読了書籍の pageCount を合算する（null は0扱い）', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 2, 1), pageCount: 200),
          book('b2', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 3, 1), pageCount: 350),
          book('b3', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 4, 1), pageCount: null),
          book('b4', status: ReadingStatus.finished,
              finishedAt: DateTime(2025, 1, 1), pageCount: 999),
        ],
        reviews: const [],
        now: now,
      );
      expect(stats.totalPages, 550);
    });

    test('authorCount は著者数を返す', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1', author: '著者A', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 1), pageCount: 100),
          book('b2', author: '著者A', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 2, 1), pageCount: 100),
          book('b3', author: '著者B', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 3, 1), pageCount: 100),
        ],
        reviews: const [],
        now: now,
      );
      expect(stats.authorCount, 2);
      expect(stats.totalFinished, 3);
    });

    test('既定値: totalPages=0', () {
      const stats = ReadingStats(
        year: 2026,
        totalFinished: 0,
        monthlyCounts: [],
        authorCounts: {},
        averageRating: null,
        pacePerMonth: 0,
      );
      expect(stats.totalPages, 0);
    });
  });

  group('ReadingStatsService.compareYears', () {
    test('前年に読了あり: 差分と符号付きラベル（正）', () {
      final books = [
        // 今年: 2冊 / 600ページ / 著者1人
        book('b1', status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 2, 1), pageCount: 300),
        book('b2', status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 3, 1), pageCount: 300),
        // 前年: 1冊 / 400ページ / 著者1人
        book('b3', status: ReadingStatus.finished,
            finishedAt: DateTime(2025, 5, 1), pageCount: 400),
      ];
      final cmp = ReadingStatsService.compareYears(
        books: books,
        reviews: const [],
        now: now,
      );
      expect(cmp.hasPreviousData, isTrue);
      expect(cmp.finishedDiff, 1);
      expect(cmp.pagesDiff, 200);
      expect(cmp.authorDiff, 0);
      expect(cmp.headLabel, '2025年 → 2026年');
      expect(cmp.finishedLabel, '+1冊');
      expect(cmp.pagesLabel, '+200ページ');
      expect(cmp.authorLabel, '±0人');
    });

    test('前年の方が多い: 符号付きラベル（負）', () {
      final books = [
        // 今年: 1冊 / 100ページ
        book('b1', status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 2, 1), pageCount: 100),
        // 前年: 3冊 / 900ページ / 著者2人
        book('b2', author: '著者A', status: ReadingStatus.finished,
            finishedAt: DateTime(2025, 1, 1), pageCount: 300),
        book('b3', author: '著者B', status: ReadingStatus.finished,
            finishedAt: DateTime(2025, 2, 1), pageCount: 300),
        book('b4', author: '著者B', status: ReadingStatus.finished,
            finishedAt: DateTime(2025, 3, 1), pageCount: 300),
      ];
      final cmp = ReadingStatsService.compareYears(
        books: books,
        reviews: const [],
        now: now,
      );
      expect(cmp.finishedDiff, -2);
      expect(cmp.pagesDiff, -800);
      expect(cmp.authorDiff, -1);
      expect(cmp.finishedLabel, '-2冊');
      expect(cmp.pagesLabel, '-800ページ');
      expect(cmp.authorLabel, '-1人');
    });

    test('差分ゼロ: ±0ラベル', () {
      final books = [
        book('b1', status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 2, 1), pageCount: 250),
        book('b2', status: ReadingStatus.finished,
            finishedAt: DateTime(2025, 2, 1), pageCount: 250),
      ];
      final cmp = ReadingStatsService.compareYears(
        books: books,
        reviews: const [],
        now: now,
      );
      expect(cmp.finishedDiff, 0);
      expect(cmp.pagesDiff, 0);
      expect(cmp.authorDiff, 0);
      expect(cmp.finishedLabel, '±0冊');
      expect(cmp.pagesLabel, '±0ページ');
      expect(cmp.authorLabel, '±0人');
    });

    test('前年データ0件でも落ちない', () {
      final books = [
        book('b1', status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 2, 1), pageCount: 120),
      ];
      final cmp = ReadingStatsService.compareYears(
        books: books,
        reviews: const [],
        now: now,
      );
      expect(cmp.hasPreviousData, isFalse);
      expect(cmp.previous.totalFinished, 0);
      expect(cmp.previous.totalPages, 0);
      expect(cmp.finishedDiff, 1);
      expect(cmp.pagesDiff, 120);
      expect(cmp.authorDiff, 1);
    });

    test('年をまたぐ読了は正しく分離される', () {
      final books = [
        book('b1', status: ReadingStatus.finished,
            finishedAt: DateTime(2025, 12, 30, 23, 59), pageCount: 100),
        book('b2', status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 1, 1, 0, 0), pageCount: 200),
        // レビュー日代用: 前年レビューのみで前年読了扱い
        book('b3', status: ReadingStatus.finished, pageCount: 50),
      ];
      final reviews = [
        review('r1', 'b3', at: DateTime(2025, 6, 1)),
      ];
      final cmp = ReadingStatsService.compareYears(
        books: books,
        reviews: reviews,
        now: now,
      );
      expect(cmp.previous.totalFinished, 2);
      expect(cmp.previous.totalPages, 150);
      expect(cmp.current.totalFinished, 1);
      expect(cmp.current.totalPages, 200);
    });
  });
}