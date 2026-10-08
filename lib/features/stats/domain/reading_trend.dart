import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/domain/genre_service.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/domain/reading_stats_service.dart';

/// 年間読書傾向（月別読了・月別読書時間・ジャンル分布）の不変モデル。
class ReadingTrend {
  /// 対象年
  final int year;

  /// 月別の読了冊数（長さ12固定。index 0 = 1月）
  final List<int> monthlyFinished;

  /// 月別の読書時間（分。長さ12固定。index 0 = 1月）
  final List<int> monthlyMinutes;

  /// 正規化ジャンル → 冊数（件数降順・同数は名前昇順で挿入済み）
  final Map<String, int> genreCounts;

  const ReadingTrend({
    required this.year,
    required this.monthlyFinished,
    required this.monthlyMinutes,
    required this.genreCounts,
  });

  /// 年間の読了総冊数
  int get totalFinished =>
      monthlyFinished.fold(0, (sum, count) => sum + count);

  /// 年間の総読書時間（分）
  int get totalMinutes => monthlyMinutes.fold(0, (sum, m) => sum + m);

  /// 読了もセッションも無い年か
  bool get isEmpty => totalFinished == 0 && totalMinutes == 0;

  /// 読了が最も多い月（1..12）。全部0なら null。同数は月の小さい方。
  int? get busiestFinishedMonth => _busiest(monthlyFinished);

  /// 読書時間が最も長い月（1..12）。全部0なら null。同数は月の小さい方。
  int? get busiestMinutesMonth => _busiest(monthlyMinutes);

  /// ジャンルの種類数
  int get genreCount => genreCounts.length;

  /// 総読書時間ラベル（'N時間M分' / 'M分'。ReadingStats.totalLabel と同一規則）
  String get totalMinutesLabel {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes分';
    if (minutes == 0) return '$hours時間';
    return '$hours時間$minutes分';
  }

  /// 月別リストの最大値を持つ月（1始まり）。全0なら null、同数は小さい月を優先。
  static int? _busiest(List<int> monthly) {
    var bestIndex = -1;
    for (var i = 0; i < monthly.length; i++) {
      if (monthly[i] <= 0) continue;
      if (bestIndex == -1 || monthly[i] > monthly[bestIndex]) {
        bestIndex = i;
      }
    }
    return bestIndex == -1 ? null : bestIndex + 1;
  }
}

/// 年間読書傾向を集計する純粋ロジックサービス。
///
/// 永続化・UI に依存しないため単体試練が容易。不正・未来日付・状態不整合は黙って除外する。
class ReadingTrendService {
  const ReadingTrendService();

  /// [year] = (now ?? DateTime.now()).year の読書傾向を算出する。
  ///
  /// - monthlyFinished: ReadingStatsService.compute の月別読了冊数を流用する
  ///   （読了判定規則の二重実装を避けるため）。
  /// - monthlyMinutes: startedAt が対象年内のセッションの durationMinutes を月別合算。
  /// - genreCounts: 対象年内に読了した書籍のジャンルを GenreService で正規化して集計。
  ReadingTrend compute({
    required List<Book> books,
    required List<Review> reviews,
    required List<ReadingSession> sessions,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final year = ref.year;

    // 月別読了冊数は既存サービスの結果をそのまま使う（規則の一元化）。
    final monthlyFinished =
        ReadingStatsService.compute(books: books, reviews: reviews, now: ref)
            .monthlyCounts;

    // 月別読書時間: startedAt が対象年内かつ ref 以前のもののみ。
    final monthlyMinutes = List<int>.filled(12, 0);
    for (final session in sessions) {
      final started = session.startedAt;
      if (started.year != year || started.isAfter(ref)) continue;
      monthlyMinutes[started.month - 1] += session.durationMinutes;
    }

    // ジャンル分布: 対象年内に読了した書籍が対象。
    // 読了日の解決規則は ReadingStatsService と同一（finishedAt 優先、
    // 無ければ今年の最初のレビュー作成日）。
    final firstReviewByBook = <String, DateTime>{};
    for (final review in reviews) {
      if (review.createdAt.year != year) continue;
      final existing = firstReviewByBook[review.bookId];
      if (existing == null || review.createdAt.isBefore(existing)) {
        firstReviewByBook[review.bookId] = review.createdAt;
      }
    }

    final counts = <String, int>{};
    for (final book in books) {
      if (book.readingStatus.name != 'finished') continue;
      final finishedAt = book.finishedAt ?? firstReviewByBook[book.id];
      if (finishedAt == null || finishedAt.year != year) continue;
      if (finishedAt.isAfter(ref)) continue;

      final genres = GenreService.canonicalList(book.genres);
      if (genres.isEmpty) {
        counts['未分類'] = (counts['未分類'] ?? 0) + 1;
        continue;
      }
      for (final genre in genres) {
        counts[genre] = (counts[genre] ?? 0) + 1;
      }
    }

    // 件数降順 → 同数はジャンル名昇順でソートした不変マップに整える。
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    return ReadingTrend(
      year: year,
      monthlyFinished: monthlyFinished,
      monthlyMinutes: monthlyMinutes,
      genreCounts: Map.unmodifiable(Map.fromEntries(entries)),
    );
  }
}