// 期間レポートの純粋ロジック。
//
// 入力（全蔵書・全レビュー・全読書セッション・期間・基準日時）から
// [PeriodReport] を副作用なく算出する。永続化・UI には依存しない。
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

import 'period_report.dart';
import 'report_period.dart';

/// 期間レポート生成サービス。
class PeriodReportService {
  const PeriodReportService();

  /// 期間レポートを算出する。
  ///
  /// - 読了の判定: `readingStatus == finished` かつ読了日が期間内。
  ///   読了日の解決は [ReadingStatsService.compute] と同一規則:
  ///   `finishedAt` を優先し、無ければその書籍の最初のレビュー作成日を
  ///   代用する。解決できなかった書籍は集計しない。
  /// - 読書時間: `startedAt` が期間内のセッションの合算
  ///   （index 0 = 期間初日の日別内訳付き）。
  /// - お気に入りレビュー: 期間内かつ rating >= 4。rating 降順 →
  ///   createdAt 降順 → id 昇順でソートし、先頭3件まで。
  /// - 不正データ（未来日付・状態不整合）は黙って除外する。
  PeriodReport build({
    required List<Book> books,
    required List<Review> reviews,
    required List<ReadingSession> sessions,
    required ReportPeriod period,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();

    // 書籍ID -> 最初のレビュー作成日（読了日の代用候補）
    final firstReviewByBook = <String, DateTime>{};
    for (final review in reviews) {
      final existing = firstReviewByBook[review.bookId];
      if (existing == null || review.createdAt.isBefore(existing)) {
        firstReviewByBook[review.bookId] = review.createdAt;
      }
    }

    // 読了書籍の収集（finishedAt ?? 最初のレビュー日）
    final finishedEntries = <(DateTime, Book)>[];
    for (final book in books) {
      if (book.readingStatus.name != 'finished') continue;
      final finishedAt = book.finishedAt ?? firstReviewByBook[book.id];
      if (finishedAt == null) continue;
      if (!period.contains(finishedAt)) continue;
      if (finishedAt.isAfter(ref)) continue;
      finishedEntries.add((finishedAt, book));
    }
    finishedEntries.sort((a, b) {
      final byDate = a.$1.compareTo(b.$1);
      if (byDate != 0) return byDate;
      final byTitle = a.$2.title.compareTo(b.$2.title);
      if (byTitle != 0) return byTitle;
      return a.$2.id.compareTo(b.$2.id);
    });
    final finishedBooks = finishedEntries.map((e) => e.$2).toList();

    // セッションの集計（合算と日別内訳）
    final dailyMinutes = List<int>.filled(period.days, 0);
    var totalMinutes = 0;
    for (final session in sessions) {
      final started = session.startedAt;
      if (!period.contains(started)) continue;
      if (started.isAfter(ref)) continue;
      final dayIndex =
          DateTime(started.year, started.month, started.day)
              .difference(period.start)
              .inDays;
      if (dayIndex < 0 || dayIndex >= dailyMinutes.length) continue;
      dailyMinutes[dayIndex] += session.durationMinutes;
      totalMinutes += session.durationMinutes;
    }

    // お気に入りレビュー（rating >= 4、期間内）
    final favorites = reviews
        .where((r) =>
            r.rating >= 4 && period.contains(r.createdAt) && !r.createdAt.isAfter(ref))
        .toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        if (byRating != 0) return byRating;
        final byDate = b.createdAt.compareTo(a.createdAt);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });
    final favoriteReviews = favorites.take(3).toList();

    return PeriodReport(
      period: period,
      finishedCount: finishedBooks.length,
      totalMinutes: totalMinutes,
      finishedBooks: finishedBooks,
      favoriteReviews: favoriteReviews,
      dailyMinutes: dailyMinutes,
    );
  }
}