// 期間レポート機能の試練（PeriodReport / PeriodReportService.build）。
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/report/domain/period_report.dart';
import 'package:book_review_app/features/report/domain/period_report_service.dart';
import 'package:book_review_app/features/report/domain/report_period.dart';

/// 試練用の書籍ヘルパー。
Book _book({
  required String id,
  String title = '本',
  String author = '著者',
  ReadingStatus status = ReadingStatus.unread,
  DateTime? finishedAt,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    isbn: '978-0-$id',
    readingStatus: status,
    finishedAt: finishedAt,
  );
}

Review _review({
  required String id,
  required String bookId,
  required int rating,
  required DateTime createdAt,
}) {
  return Review(id: id, bookId: bookId, rating: rating, text: 'x', createdAt: createdAt);
}

ReadingSession _session({
  required String id,
  required DateTime startedAt,
  required int minutes,
}) {
  return ReadingSession(id: id, startedAt: startedAt, durationMinutes: minutes);
}

void main() {
  final now = DateTime(2026, 10, 13, 9, 0);
  final week = ReportPeriod.weekOf(DateTime(2026, 10, 13)); // 10/12〜10/18

  group('build: 読了本', () {
    test('期間内の読了（finishedAt）を数える', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 12, 15, 0),
          ),
        ],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedCount, 1);
      expect(report.finishedBooks.single.id, 'b1');
    });
    test('期間の境界: start 当日は含む', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 12, 0, 0),
          ),
        ],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedCount, 1);
    });
    test('endExclusive 当日（10/19）は含まない', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 19, 0, 0),
          ),
        ],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedCount, 0);
    });
    test('読了状態でも finishedAt が無くレビューも無い本は除外', () {
      final report = PeriodReportService().build(
        books: [_book(id: 'b1', status: ReadingStatus.finished)],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedCount, 0);
    });
    test('finishedAt null は最初のレビュー作成日で解決する', () {
      final report = PeriodReportService().build(
        books: [_book(id: 'b1', status: ReadingStatus.finished)],
        reviews: [
          _review(
            id: 'r1',
            bookId: 'b1',
            rating: 3,
            createdAt: DateTime(2026, 10, 13, 8, 0),
          ),
        ],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedCount, 1);
    });
    test('レビュー解決は同一書籍の最初（最古）のレビュー日', () {
      final report = PeriodReportService().build(
        books: [_book(id: 'b1', status: ReadingStatus.finished)],
        reviews: [
          _review(
            id: 'r2',
            bookId: 'b1',
            rating: 3,
            createdAt: DateTime(2026, 10, 13, 8, 0),
          ),
          _review(
            id: 'r1',
            bookId: 'b1',
            rating: 3,
            createdAt: DateTime(2026, 10, 12, 10, 0),
          ),
        ],
        sessions: const [],
        period: week,
        now: now,
      );
      // 両方期間内なので数に変化はないが、解決日が期間外なら除外される検証。
      expect(report.finishedCount, 1);
    });
    test('レビュー解決日が期間外なら除外', () {
      final p2 = ReportPeriod.monthOf(DateTime(2026, 10, 13)); // 10月
      final report = PeriodReportService().build(
        books: [_book(id: 'b1', status: ReadingStatus.finished)],
        reviews: [
          _review(
            id: 'r1',
            bookId: 'b1',
            rating: 3,
            createdAt: DateTime(2026, 9, 30, 10, 0),
          ),
        ],
        sessions: const [],
        period: ReportPeriod.weekOf(DateTime(2026, 10, 13)),
        now: now,
      );
      expect(report.finishedCount, 0);
      expect(p2.days, 31);
    });
    test('未来日付の読了は除外', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 15, 0, 0),
          ),
        ],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now, // 10/13 09:00
      );
      expect(report.finishedCount, 0);
    });
    test('finishedAt が now と同じ瞬間なら含む', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 13, 9, 0),
          ),
        ],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedCount, 1);
    });
    test('未読了状態の本は finishedAt があっても集計しない', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.reading,
            finishedAt: DateTime(2026, 10, 13, 0, 0),
          ),
        ],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedCount, 0);
    });
    test('finishedBooks は読了日昇順・同時刻は title/id 昇順', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b2',
            title: '乙',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 13, 0, 0),
          ),
          _book(
            id: 'b3',
            title: '丙',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 13, 8, 0),
          ),
          _book(
            id: 'b1',
            title: '乙',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 13, 0, 0),
          ),
        ],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedBooks.map((b) => b.id).toList(), ['b1', 'b2', 'b3']);
    });
    test('複数書籍の合算', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 12, 0, 0),
          ),
          _book(
            id: 'b2',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 13, 8, 0),
          ),
          _book(
            id: 'b3',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 16, 0, 0), // 未来 → 除外
          ),
        ],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.finishedCount, 2);
    });
  });

  group('build: セッション合算', () {
    test('totalMinutes は期間内セッションの合算', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: const [],
        sessions: [
          _session(id: 's1', startedAt: DateTime(2026, 10, 12, 21, 0), minutes: 60),
          _session(id: 's2', startedAt: DateTime(2026, 10, 13, 8, 0), minutes: 30),
          _session(id: 's3', startedAt: DateTime(2026, 10, 11, 8, 0), minutes: 120),
          _session(id: 's4', startedAt: DateTime(2026, 10, 19, 8, 0), minutes: 45),
        ],
        period: week,
        now: now,
      );
      expect(report.totalMinutes, 90);
    });
    test('dailyMinutes の長さは period.days', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.dailyMinutes.length, 7);
      expect(report.dailyMinutes, everyElement(0));
    });
    test('dailyMinutes の index は start 起算（0=10/12）', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: const [],
        sessions: [
          _session(id: 's1', startedAt: DateTime(2026, 10, 13, 8, 0), minutes: 20),
          _session(id: 's2', startedAt: DateTime(2026, 10, 12, 23, 0), minutes: 5),
        ],
        period: week,
        now: now,
      );
      expect(report.dailyMinutes[0], 5);
      expect(report.dailyMinutes[1], 20);
      expect(report.maxDailyMinutes, 20);
    });
    test('同一日の複数セッションは加算される', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: const [],
        sessions: [
          _session(id: 's1', startedAt: DateTime(2026, 10, 12, 7, 0), minutes: 15),
          _session(id: 's2', startedAt: DateTime(2026, 10, 12, 22, 0), minutes: 45),
        ],
        period: week,
        now: now,
      );
      expect(report.dailyMinutes[0], 60);
      expect(report.totalMinutes, 60);
    });
    test('未来のセッション（now 以降）は除外', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: const [],
        sessions: [
          _session(id: 's1', startedAt: DateTime(2026, 10, 14, 0, 0), minutes: 60),
        ],
        period: week,
        now: now,
      );
      expect(report.totalMinutes, 0);
    });
    test('startedAt が now と同じ瞬間なら含む', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: const [],
        sessions: [
          _session(id: 's1', startedAt: DateTime(2026, 10, 13, 9, 0), minutes: 10),
        ],
        period: week,
        now: now,
      );
      expect(report.totalMinutes, 10);
    });
  });

  group('build: favoriteReviews', () {
    test('rating >= 4 のレビューのみ（3は除外）', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: [
          _review(id: 'r1', bookId: 'b1', rating: 3, createdAt: DateTime(2026, 10, 12, 0, 0)),
          _review(id: 'r2', bookId: 'b1', rating: 4, createdAt: DateTime(2026, 10, 13, 1, 0)),
          _review(id: 'r3', bookId: 'b1', rating: 5, createdAt: DateTime(2026, 10, 13, 2, 0)),
        ],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.favoriteReviews.map((r) => r.id).toList(), ['r3', 'r2']);
    });
    test('rating 降順 → createdAt 降順 → id 昇順', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: [
          _review(id: 'a', bookId: 'b', rating: 4, createdAt: DateTime(2026, 10, 13, 1, 0)),
          _review(id: 'b', bookId: 'b', rating: 4, createdAt: DateTime(2026, 10, 13, 1, 0)),
          _review(id: 'c', bookId: 'b', rating: 5, createdAt: DateTime(2026, 10, 12, 0, 0)),
        ],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.favoriteReviews.map((r) => r.id).toList(), ['c', 'a', 'b']);
    });
    test('先頭3件までに制限される', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: [
          for (var i = 1; i <= 5; i++)
            _review(
              id: 'r$i',
              bookId: 'b',
              rating: 5,
              createdAt: DateTime(2026, 10, 12, i, 0),
            ),
        ],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.favoriteReviews.length, 3);
    });
    test('期間外・未来のレビューは除外', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: [
          _review(id: 'r1', bookId: 'b', rating: 5, createdAt: DateTime(2026, 10, 11, 0, 0)),
          _review(id: 'r2', bookId: 'b', rating: 5, createdAt: DateTime(2026, 10, 15, 0, 0)),
          _review(id: 'r3', bookId: 'b', rating: 5, createdAt: DateTime(2026, 10, 13, 0, 0)),
        ],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.favoriteReviews.single.id, 'r3');
    });
  });

  group('build: 空期間', () {
    test('何も無ければ空レポート', () {
      final report = PeriodReportService().build(
        books: const [],
        reviews: const [],
        sessions: const [],
        period: week,
        now: now,
      );
      expect(report.isEmpty, isTrue);
      expect(report.finishedCount, 0);
      expect(report.totalMinutes, 0);
      expect(report.favoriteReviews, isEmpty);
      expect(report.maxDailyMinutes, 0);
    });
    test('データはあるが期間外なら空', () {
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 1, 0, 0),
          ),
        ],
        reviews: const [],
        sessions: [_session(id: 's1', startedAt: DateTime(2026, 10, 1, 8, 0), minutes: 30)],
        period: week,
        now: now,
      );
      expect(report.isEmpty, isTrue);
    });
  });

  group('PeriodReport ラベル', () {
    test('totalMinutesLabel: 12時間30分 / 45分 / 0分', () {
      expect(_mkReport(750).totalMinutesLabel, '12時間30分');
      expect(_mkReport(45).totalMinutesLabel, '45分');
      expect(_mkReport(0).totalMinutesLabel, '0分');
    });
    test('ちょうど1時間は「1時間」', () {
      expect(_mkReport(60).totalMinutesLabel, '1時間');
    });
  });

  group('月次レポート', () {
    test('月次で読了とセッションを集計する', () {
      final month = ReportPeriod.monthOf(DateTime(2026, 10, 13));
      final report = PeriodReportService().build(
        books: [
          _book(
            id: 'b1',
            status: ReadingStatus.finished,
            finishedAt: DateTime(2026, 10, 5, 0, 0),
          ),
        ],
        reviews: const [],
        sessions: [
          _session(id: 's1', startedAt: DateTime(2026, 10, 1, 8, 0), minutes: 90),
          _session(id: 's2', startedAt: DateTime(2026, 9, 30, 8, 0), minutes: 30),
          _session(id: 's3', startedAt: DateTime(2026, 11, 1, 8, 0), minutes: 30),
        ],
        period: month,
        now: now,
      );
      expect(report.finishedCount, 1);
      expect(report.totalMinutes, 90);
      expect(report.dailyMinutes.length, 31);
      expect(report.dailyMinutes[0], 90);
      expect(report.isEmpty, isFalse);
    });
  });
}

PeriodReport _mkReport(int totalMinutes) {
  return PeriodReport(
    period: ReportPeriod.monthOf(DateTime(2026, 10, 13)),
    finishedCount: 0,
    totalMinutes: totalMinutes,
    finishedBooks: const [],
    favoriteReviews: const [],
    dailyMinutes: [totalMinutes],
  );
}