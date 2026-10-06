import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';

import 'year_comparison.dart';

/// 年間読書統計の不変モデル。
///
/// 月別読了冊数・著者別読了分布・平均評価・読了ペースを保持する。
class ReadingStats {
  /// 統計の対象年
  final int year;

  /// 今年読了した書籍の総冊数
  final int totalFinished;

  /// 月別の読了冊数（index 0 = 1月、長さ 12）
  final List<int> monthlyCounts;

  /// 著者別の読了冊数（読了冊数の降順・同数は著者名昇順）
  final Map<String, int> authorCounts;

  /// 今年のレビュー平均評価（1.0〜5.0。レビュー無しは null）
  final double? averageRating;

  /// 読了ペース（経過月ベースの月平均読了冊数）
  final double pacePerMonth;

  /// 今年読了した書籍の総ページ数（pageCount 不明は0として合算）
  final int totalPages;

  const ReadingStats({
    required this.year,
    required this.totalFinished,
    required this.monthlyCounts,
    required this.authorCounts,
    required this.averageRating,
    required this.pacePerMonth,
    this.totalPages = 0,
  });

  /// 読了書籍に登場した著者の人数
  int get authorCount => authorCounts.length;

  /// 最も多く読了した著者（同数の先頭・空なら null）
  String? get topAuthor =>
      authorCounts.keys.isEmpty ? null : authorCounts.keys.first;
}

/// 読書統計ダッシュボードの純粋ロジック。
///
/// 入力（全蔵書・全レビュー・基準日時）から年間統計を副作用なく算出する。
/// 永続化・UI には依存しないため単体試練が容易。
class ReadingStatsService {
  ReadingStatsService._();

  /// 年間読書統計を算出する。
  ///
  /// - 読了の判定: `readingStatus == finished` かつ `finishedAt` が設定済み。
  ///   `finishedAt` が未設定の読了書籍は、同一書籍の今年のレビュー作成日を
  ///   読了日の代用として使用する（同一書籍の複数レビューは最初の1件のみ）。
  /// - 未来日付・状態不整合（finishedAt 有りだが未読了状態）は集計しない。
  static ReadingStats compute({
    required List<Book> books,
    required List<Review> reviews,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final year = ref.year;

    // 読了日の解決: finishedAt を優先し、無ければ今年の最初のレビュー日。
    final finishedThisYear = <DateTime>[];
    final authorsThisYear = <String, int>{};
    var totalPages = 0;

    // 書籍ID -> 今年の最初のレビュー作成日（レビューは後で照合するため収集）
    final firstReviewByBook = <String, DateTime>{};
    for (final review in reviews) {
      if (review.createdAt.year != year) continue;
      final existing = firstReviewByBook[review.bookId];
      if (existing == null || review.createdAt.isBefore(existing)) {
        firstReviewByBook[review.bookId] = review.createdAt;
      }
    }

    // 今年のレビューの平均評価
    double? averageRating;
    final yearReviews =
        reviews.where((r) => r.createdAt.year == year).toList();
    if (yearReviews.isNotEmpty) {
      var total = 0;
      for (final review in yearReviews) {
        total += review.rating;
      }
      averageRating = total / yearReviews.length;
    }

    for (final book in books) {
      if (book.readingStatus.name != 'finished') continue;

      final finishedAt = book.finishedAt ?? firstReviewByBook[book.id];
      if (finishedAt == null || finishedAt.year != year) continue;
      if (finishedAt.isAfter(ref)) continue;

      finishedThisYear.add(finishedAt);
      totalPages += book.pageCount ?? 0;
      final author = book.author.trim().isEmpty ? '（著者不明）' : book.author;
      authorsThisYear[author] = (authorsThisYear[author] ?? 0) + 1;
    }

    final monthlyCounts = List.filled(12, 0);
    for (final date in finishedThisYear) {
      monthlyCounts[date.month - 1]++;
    }

    final authorEntries = authorsThisYear.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    // 経過月数: 1月〜now の月。平均は切り上げ（端数月も1ヶ月と数える）。
    final elapsedMonths = ref.month;
    final pace = finishedThisYear.isEmpty
        ? 0.0
        : finishedThisYear.length / elapsedMonths;

    return ReadingStats(
      year: year,
      totalFinished: finishedThisYear.length,
      monthlyCounts: monthlyCounts,
      authorCounts: Map.unmodifiable(Map.fromEntries(authorEntries)),
      averageRating: averageRating,
      pacePerMonth: pace,
      totalPages: totalPages,
    );
  }

  /// 対象年と前年の読書統計を比較する。
  ///
  /// 前年は `DateTime(ref.year - 1, 12, 31, 23, 59, 59)` を基準日として算出する
  /// ため、前年12/31当日の読了も取りこぼさず1年分の全データが集計対象になる。
  static YearComparison compareYears({
    required List<Book> books,
    required List<Review> reviews,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final current = compute(books: books, reviews: reviews, now: ref);
    final previous = compute(
      books: books,
      reviews: reviews,
      now: DateTime(ref.year - 1, 12, 31, 23, 59, 59),
    );
    return YearComparison(current: current, previous: previous);
  }
}
