// 期間レポート（モデル）。
//
// ある集計期間における読了・読書時間・お気に入りレビューの統計を保持する。
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';

import 'report_period.dart';

/// 期間レポートの不変モデル。
class PeriodReport {
  /// 集計対象の期間。
  final ReportPeriod period;

  /// 期間内に読了した書籍の冊数。
  final int finishedCount;

  /// 期間内の読書時間の合計（分）。
  final int totalMinutes;

  /// 期間内に読了した書籍（読了日の昇順）。
  final List<Book> finishedBooks;

  /// 期間内の高評価レビュー（先頭3件まで）。
  final List<Review> favoriteReviews;

  /// 日別の読書時間（分）。長さは [ReportPeriod.days] と一致し、
  /// index 0 = 期間初日の分。
  final List<int> dailyMinutes;

  PeriodReport({
    required this.period,
    required this.finishedCount,
    required this.totalMinutes,
    required this.finishedBooks,
    required this.favoriteReviews,
    required this.dailyMinutes,
  });

  /// レポートが空（集計対象が何も無い）か。
  bool get isEmpty =>
      finishedCount == 0 &&
      totalMinutes == 0 &&
      finishedBooks.isEmpty &&
      favoriteReviews.isEmpty;

  /// 読書時間の合計を人間可読なラベルで返す（'12時間30分' / '45分' / '0分'）。
  String get totalMinutesLabel {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes分';
    if (minutes == 0) return '$hours時間';
    return '$hours時間$minutes分';
  }

  /// 日別読書時間の最大値（空なら 0）。
  int get maxDailyMinutes =>
      dailyMinutes.isEmpty ? 0 : dailyMinutes.reduce((a, b) => a > b ? a : b);
}