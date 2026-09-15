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
  }) {
    return Book(
      id: id,
      title: '本$id',
      author: author,
      isbn: '',
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

  group('ReadingStatsService.compute', () {
    test('空入力は全項目ゼロ', () {
      final stats = ReadingStatsService.compute(
        books: const [],
        reviews: const [],
        now: now,
      );
      expect(stats.year, 2026);
      expect(stats.totalFinished, 0);
      expect(stats.monthlyCounts, List.filled(12, 0));
      expect(stats.authorCounts, isEmpty);
      expect(stats.averageRating, isNull);
      expect(stats.pacePerMonth, 0.0);
    });

    test('finishedAt の月に読了として集計する', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1',
              status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 3, 10)),
          book('b2',
              status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 3, 20)),
          book('b3',
              status: ReadingStatus.finished,
              finishedAt: DateTime(2025, 1, 1)),
        ],
        reviews: const [],
        now: now,
      );
      expect(stats.totalFinished, 2);
      expect(stats.monthlyCounts[2], 2);
      expect(stats.monthlyCounts[0], 0);
    });

    test('finishedAt が無い読了書籍はレビュー作成日の月で集計する', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1', status: ReadingStatus.finished),
        ],
        reviews: [review('r1', 'b1', at: DateTime(2026, 7, 5))],
        now: now,
      );
      expect(stats.totalFinished, 1);
      expect(stats.monthlyCounts[6], 1);
    });

    test('同一書籍の複数レビューは1冊として数える', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1', status: ReadingStatus.finished),
        ],
        reviews: [
          review('r1', 'b1', at: DateTime(2026, 2, 1)),
          review('r2', 'b1', at: DateTime(2026, 2, 20)),
          review('r3', 'b1', at: DateTime(2026, 4, 1)),
        ],
        now: now,
      );
      expect(stats.totalFinished, 1);
      expect(stats.monthlyCounts[1], 1);
      expect(stats.monthlyCounts[3], 0);
    });

    test('未来の読了は集計しない', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1',
              status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 12, 1)),
        ],
        reviews: const [],
        now: now,
      );
      expect(stats.totalFinished, 0);
    });

    test('未読・読書中は集計しない', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1', status: ReadingStatus.reading),
          book('b2'),
        ],
        reviews: const [],
        now: now,
      );
      expect(stats.totalFinished, 0);
    });

    test('読了日が不正（finishedAt有りだが未読了状態）は集計しない', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1', finishedAt: DateTime(2026, 1, 1)),
        ],
        reviews: const [],
        now: now,
      );
      expect(stats.totalFinished, 0);
    });

    test('著者別読了分布を降順で返す', () {
      final stats = ReadingStatsService.compute(
        books: [
          book('b1', author: '夏目', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 1)),
          book('b2', author: '夏目', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 2, 1)),
          book('b3', author: '芥川', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 3, 1)),
        ],
        reviews: const [],
        now: now,
      );
      expect(stats.authorCounts['夏目'], 2);
      expect(stats.authorCounts['芥川'], 1);
      expect(
        stats.authorCounts.keys.toList(),
        ['夏目', '芥川'],
      );
    });

    test('今年のレビュー平均評価を返す（レビュー無しはnull）', () {
      final stats = ReadingStatsService.compute(
        books: const [],
        reviews: [
          review('r1', 'b1', rating: 5, at: DateTime(2026, 1, 1)),
          review('r2', 'b2', rating: 3, at: DateTime(2026, 2, 1)),
        ],
        now: now,
      );
      expect(stats.averageRating, closeTo(4.0, 0.001));
    });

    test('昨年のレビューは平均評価に含めない', () {
      final stats = ReadingStatsService.compute(
        books: const [],
        reviews: [
          review('r1', 'b1', rating: 5, at: DateTime(2025, 1, 1)),
        ],
        now: now,
      );
      expect(stats.averageRating, isNull);
    });

    test('読了ペース = 経過月ベースの月平均（切り上げ）', () {
      // 9/15 时点で経過月は 9ヶ月(1〜9月)。3冊読了なら 3/9。
      final stats = ReadingStatsService.compute(
        books: [
          for (var i = 1; i <= 3; i++)
            book('b$i',
                status: ReadingStatus.finished,
                finishedAt: DateTime(2026, i, 10)),
        ],
        reviews: const [],
        now: now,
      );
      expect(stats.pacePerMonth, closeTo(3 / 9, 0.001));
    });

    test('1月1日時点(now)でもゼロ除算しない', () {
      final stats = ReadingStatsService.compute(
        books: const [],
        reviews: const [],
        now: DateTime(2026, 1, 1),
      );
      expect(stats.pacePerMonth, 0.0);
    });
  });
}
