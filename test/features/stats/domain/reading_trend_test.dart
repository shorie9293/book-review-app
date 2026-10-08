import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/domain/reading_stats_service.dart';
import 'package:book_review_app/features/stats/domain/reading_trend.dart';
import 'package:flutter_test/flutter_test.dart';

/// ReadingTrend / ReadingTrendService の単体試練。
///
/// 基準日時は 2026年10月8日 12:00 固定（ローカルタイム）で決定的に検証する。
void main() {
  final ref = DateTime(2026, 10, 8, 12);

  Book book(
    String id, {
    ReadingStatus status = ReadingStatus.unread,
    DateTime? finishedAt,
    List<String> genres = const [],
  }) {
    return Book(
      id: id,
      title: '本$id',
      author: '著者$id',
      isbn: 'isbn-$id',
      genres: genres,
      readingStatus: status,
      finishedAt: finishedAt,
    );
  }

  Review review(String id, String bookId, DateTime createdAt) {
    return Review(id: id, bookId: bookId, rating: 4, text: '', createdAt: createdAt);
  }

  ReadingSession session(String id, DateTime startedAt, [int minutes = 30]) {
    return ReadingSession(id: id, startedAt: startedAt, durationMinutes: minutes);
  }

  group('ReadingTrend モデルの getters', () {
    test('totalFinished は monthlyFinished の合計', () {
      ReadingTrend trend = ReadingTrend(
        year: 2026,
        monthlyFinished: [1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 4],
        monthlyMinutes: List.filled(12, 0),
        genreCounts: {},
      );
      expect(trend.totalFinished, 10);
    });

    test('totalMinutes は monthlyMinutes の合計', () {
      ReadingTrend trend = ReadingTrend(
        year: 2026,
        monthlyFinished: List.filled(12, 0),
        monthlyMinutes: [10, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 70],
        genreCounts: {},
      );
      expect(trend.totalMinutes, 100);
    });

    test('isEmpty は totalFinished==0 かつ totalMinutes==0', () {
      ReadingTrend empty = ReadingTrend(
        year: 2026,
        monthlyFinished: List.filled(12, 0),
        monthlyMinutes: List.filled(12, 0),
        genreCounts: {},
      );
      ReadingTrend minutesOnly = ReadingTrend(
        year: 2026,
        monthlyFinished: List.filled(12, 0),
        monthlyMinutes: [1, ...List.filled(11, 0)],
        genreCounts: {},
      );
      ReadingTrend finishedOnly = ReadingTrend(
        year: 2026,
        monthlyFinished: [0, 1, ...List.filled(10, 0)],
        monthlyMinutes: List.filled(12, 0),
        genreCounts: {},
      );
      expect(empty.isEmpty, isTrue);
      expect(minutesOnly.isEmpty, isFalse);
      expect(finishedOnly.isEmpty, isFalse);
    });

    test('busiestFinishedMonth は最大月（1始まり）。同数は月の小さい方、全0はnull', () {
      ReadingTrend tie = ReadingTrend(
        year: 2026,
        monthlyFinished: [0, 3, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0],
        monthlyMinutes: List.filled(12, 0),
        genreCounts: {},
      );
      ReadingTrend allZero = ReadingTrend(
        year: 2026,
        monthlyFinished: List.filled(12, 0),
        monthlyMinutes: List.filled(12, 0),
        genreCounts: {},
      );
      ReadingTrend single = ReadingTrend(
        year: 2026,
        monthlyFinished: [0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0],
        monthlyMinutes: List.filled(12, 0),
        genreCounts: {},
      );
      expect(tie.busiestFinishedMonth, 2); // 同数3 → 2月（小さい方）
      expect(allZero.busiestFinishedMonth, isNull);
      expect(single.busiestFinishedMonth, 10);
    });

    test('busiestMinutesMonth は最大月（1始まり）。同数は月の小さい方、全0はnull', () {
      ReadingTrend tie = ReadingTrend(
        year: 2026,
        monthlyFinished: List.filled(12, 0),
        monthlyMinutes: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90, 90],
        genreCounts: {},
      );
      expect(tie.busiestMinutesMonth, 11);
      ReadingTrend allZero = ReadingTrend(
        year: 2026,
        monthlyFinished: List.filled(12, 0),
        monthlyMinutes: List.filled(12, 0),
        genreCounts: {},
      );
      expect(allZero.busiestMinutesMonth, isNull);
    });

    test('genreCount は genreCounts の長さ', () {
      ReadingTrend trend = ReadingTrend(
        year: 2026,
        monthlyFinished: List.filled(12, 0),
        monthlyMinutes: List.filled(12, 0),
        genreCounts: {'sf': 2, 'history': 1},
      );
      expect(trend.genreCount, 2);
    });

    test('totalMinutesLabel の境界（ReadingStats.totalLabel と同一規則）', () {
      ReadingTrend withMinutes(int minutes) => ReadingTrend(
            year: 2026,
            monthlyFinished: List.filled(12, 0),
            monthlyMinutes: [minutes, ...List.filled(11, 0)],
            genreCounts: {},
          );
      expect(withMinutes(0).totalMinutesLabel, '0分');
      expect(withMinutes(59).totalMinutesLabel, '59分');
      expect(withMinutes(60).totalMinutesLabel, '1時間');
      expect(withMinutes(61).totalMinutesLabel, '1時間1分');
      expect(withMinutes(125).totalMinutesLabel, '2時間5分');
    });
  });

  group('ReadingTrendService.compute', () {
    test('空入力 → 全0・isEmpty・busiest* null・genreCounts 空', () {
      final trend = const ReadingTrendService().compute(
        books: const [],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.year, 2026);
      expect(trend.monthlyFinished, List.filled(12, 0));
      expect(trend.monthlyMinutes, List.filled(12, 0));
      expect(trend.monthlyFinished.length, 12);
      expect(trend.monthlyMinutes.length, 12);
      expect(trend.isEmpty, isTrue);
      expect(trend.busiestFinishedMonth, isNull);
      expect(trend.busiestMinutesMonth, isNull);
      expect(trend.genreCounts, isEmpty);
    });

    test('複数月にまたがる読了が月別に正しく集計される', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished, finishedAt: DateTime(2026, 1, 15)),
          book('b2', status: ReadingStatus.finished, finishedAt: DateTime(2026, 3, 2)),
          book('b3', status: ReadingStatus.finished, finishedAt: DateTime(2026, 3, 20)),
          book('b4', status: ReadingStatus.finished, finishedAt: DateTime(2026, 12, 31)),
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.monthlyFinished[0], 1);
      expect(trend.monthlyFinished[2], 2);
      expect(trend.monthlyFinished[11], 0); // 12/31 は ref より未来 → 除外
      expect(trend.totalFinished, 3);
      expect(trend.busiestFinishedMonth, 3);
    });

    test('finishedAt が無い読了書籍は今年の最初のレビュー作成日で判定される', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished),
        ],
        reviews: [
          review('r1', 'b1', DateTime(2026, 5, 10)),
          review('r2', 'b1', DateTime(2026, 2, 1)), // 最初のレビューは2月
        ],
        sessions: const [],
        now: ref,
      );
      expect(trend.monthlyFinished[1], 1); // 2月
      expect(trend.totalFinished, 1);
    });

    test('year 外の読了・セッションは混入しない', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished, finishedAt: DateTime(2025, 6, 1)),
          book('b2', status: ReadingStatus.finished, finishedAt: DateTime(2027, 1, 1)),
        ],
        reviews: const [],
        sessions: [
          session('s1', DateTime(2025, 12, 31), 60),
          session('s2', DateTime(2027, 1, 1), 30),
        ],
        now: ref,
      );
      expect(trend.monthlyFinished, List.filled(12, 0));
      expect(trend.monthlyMinutes, List.filled(12, 0));
      expect(trend.isEmpty, isTrue);
    });

    test('未来日付の finishedAt（> ref）は黙って除外される', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished, finishedAt: DateTime(2026, 10, 8, 12, 0, 1)),
          book('b2', status: ReadingStatus.finished, finishedAt: DateTime(2026, 12, 1)),
          book('b3', status: ReadingStatus.finished, finishedAt: DateTime(2026, 10, 8, 11)),
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.monthlyFinished[9], 1); // b3 のみ
      expect(trend.totalFinished, 1);
    });

    test('未来 startedAt のセッションは除外される', () {
      final trend = const ReadingTrendService().compute(
        books: const [],
        reviews: const [],
        sessions: [
          session('s1', DateTime(2026, 4, 1), 30),
          session('s2', DateTime(2026, 10, 8, 12, 30), 90), // 未来
          session('s3', DateTime(2026, 10, 8, 12)), // ref ちょうど（未来でない）
        ],
        now: ref,
      );
      expect(trend.monthlyMinutes[3], 30);
      expect(trend.monthlyMinutes[9], 30); // s3 は ref ちょうど → 未来でないので計上
      expect(trend.totalMinutes, 60);
    });

    test('monthlyMinutes は year 内のセッションを月別合算', () {
      final trend = const ReadingTrendService().compute(
        books: const [],
        reviews: const [],
        sessions: [
          session('s1', DateTime(2026, 1, 5), 40),
          session('s2', DateTime(2026, 1, 20), 20),
          session('s3', DateTime(2026, 7, 1), 90),
        ],
        now: ref,
      );
      expect(trend.monthlyMinutes[0], 60);
      expect(trend.monthlyMinutes[6], 90);
      expect(trend.totalMinutes, 150);
      expect(trend.busiestMinutesMonth, 7);
    });

    test('busiestFinishedMonth のタイブレークは月の小さい方', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished, finishedAt: DateTime(2026, 8, 1)),
          book('b2', status: ReadingStatus.finished, finishedAt: DateTime(2026, 4, 1)),
          book('b3', status: ReadingStatus.finished, finishedAt: DateTime(2026, 8, 2)),
          book('b4', status: ReadingStatus.finished, finishedAt: DateTime(2026, 4, 2)),
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.busiestFinishedMonth, 4);
    });

    test('ジャンル正規化: 全角/大文字の揺れが同一ジャンルに統合される', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 1), genres: ['ＳＦ']),
          book('b2', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 2, 1), genres: ['sf']),
          book('b3', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 3, 1), genres: ['Sf ', '文学']),
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.genreCounts['sf'], 3);
      expect(trend.genreCounts['文学'], 1);
      expect(trend.genreCount, 2);
    });

    test('genres が空の読了書籍は 未分類 バケットに1件加算', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 1), genres: []),
          book('b2', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 2), genres: ['SF']),
          book('b3', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 3), genres: ['   ']), // 空白のみも空扱い
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.genreCounts['未分類'], 2);
      expect(trend.genreCounts['sf'], 1);
    });

    test('genreCounts は件数降順 → 同数はジャンル名昇順で挿入される', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 1), genres: ['z zz', 'A B']),
          book('b2', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 2), genres: ['a b']),
          book('b3', status: ReadingStatus.finished,
              finishedAt: DateTime(2026, 1, 3), genres: ['a b', 'c d', 'e f']),
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.genreCounts.keys.toList(), ['a b', 'c d', 'e f', 'z zz']);
      expect(trend.genreCounts['a b'], 3);
    });

    test('year 外の読了書籍のジャンルは集計されない', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.finished,
              finishedAt: DateTime(2025, 6, 1), genres: ['SF']),
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.genreCounts, isEmpty);
    });

    test('未読了（積読・読書中）書籍は月別・ジャンル共に対象外', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.unread, genres: ['SF']),
          book('b2', status: ReadingStatus.reading, finishedAt: DateTime(2026, 1, 1)),
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.monthlyFinished, List.filled(12, 0));
      expect(trend.genreCounts, isEmpty);
    });

    test('状態不整合（finishedAt 有りだが未読了状態）は黙って除外', () {
      final trend = const ReadingTrendService().compute(
        books: [
          book('b1', status: ReadingStatus.reading, finishedAt: DateTime(2026, 1, 1)),
        ],
        reviews: const [],
        sessions: const [],
        now: ref,
      );
      expect(trend.totalFinished, 0);
    });

    test('不変条件: monthlyFinished は ReadingStatsService.compute().monthlyCounts と完全一致', () {
      final books = [
        book('b1', status: ReadingStatus.finished, finishedAt: DateTime(2026, 1, 15)),
        book('b2', status: ReadingStatus.finished), // レビュー日代用
        book('b3', status: ReadingStatus.finished, finishedAt: DateTime(2026, 10, 8, 12, 0, 1)), // 未来 → 除外
        book('b4', status: ReadingStatus.finished, finishedAt: DateTime(2025, 3, 3)), // 前年 → 除外
        book('b5', status: ReadingStatus.reading, finishedAt: DateTime(2026, 2, 2)), // 不整合 → 除外
        book('b6', status: ReadingStatus.finished, finishedAt: DateTime(2026, 5, 9)),
      ];
      final reviews = [
        review('r1', 'b2', DateTime(2026, 4, 1)),
        review('r2', 'b2', DateTime(2026, 3, 1)),
      ];
      final trend = const ReadingTrendService().compute(
        books: books,
        reviews: reviews,
        sessions: const [],
        now: ref,
      );
      final stats = ReadingStatsService.compute(
        books: books,
        reviews: reviews,
        now: ref,
      );
      expect(trend.monthlyFinished, stats.monthlyCounts);
      expect(trend.totalFinished, stats.totalFinished);
      expect(trend.year, stats.year);
    });

    test('now 未指定時は DateTime.now() の年を使う（例外を投げない）', () {
      final trend = const ReadingTrendService().compute(
        books: const [],
        reviews: const [],
        sessions: const [],
      );
      expect(trend.year, DateTime.now().year);
    });
  });
}