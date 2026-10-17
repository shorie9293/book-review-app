import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/badges/domain/achievement_badge.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

/// 実績バッジの計算サービス（純粋・状態を持たない）。
class AchievementBadgeService {
  const AchievementBadgeService();

  /// 与えられたデータから実績バッジのコレクションを構築する。
  ///
  /// [now] はテスト可能にするため注入可能。未指定時のみ `DateTime.now()` を使う
  /// （本体が直接呼ぶのはこの1箇所のみ）。
  AchievementBadgeCollection build({
    required List<Book> books,
    required List<Review> reviews,
    required List<ReadingSession> sessions,
    DateTime Function()? now,
    List<AchievementBadgeDefinition> definitions = kAchievementBadges,
  }) {
    final currentAt = now ?? DateTime.now;
    final today = currentAt().toLocal();
    final todayDate = DateTime(today.year, today.month, today.day);

    // --- 各メトリクスの現在値 ---
    var finishedCount = 0;
    final genreSet = <String>{};
    for (final book in books) {
      if (book.readingStatus == ReadingStatus.finished) {
        finishedCount++;
        for (final raw in book.genres) {
          final genre = _normalizeGenre(raw);
          if (genre.isNotEmpty) genreSet.add(genre);
        }
      }
    }

    final streakDays = _consecutiveDays(sessions, todayDate);

    var totalMinutes = 0;
    for (final session in sessions) {
      totalMinutes += session.durationMinutes;
    }

    final currentByCategory = <AchievementCategory, int>{
      AchievementCategory.reading: finishedCount,
      AchievementCategory.streak: streakDays,
      AchievementCategory.genre: genreSet.length,
      AchievementCategory.review: reviews.length,
      AchievementCategory.time: totalMinutes,
    };

    // --- 定義を安定ソート（category → requiredCount → id） ---
    final sorted = _sortDefinitions(definitions);

    // --- 進捗構築 ---
    final progresses = <AchievementBadgeProgress>[];
    for (final definition in sorted) {
      final current = currentByCategory[definition.category] ?? 0;
      progresses.add(AchievementBadgeProgress(
        definition: definition,
        current: current,
      ));
    }

    return AchievementBadgeCollection(progresses: progresses);
  }

  /// ジャンル名を正規化する（trim・全角スペース→半角・連続空白圧縮）。
  String _normalizeGenre(String raw) {
    final replaced = raw.replaceAll('\u3000', ' ').trim();
    if (replaced.isEmpty) return '';
    return replaced.replaceAll(RegExp(' +'), ' ');
  }

  /// セッションから、今日または昨日から遡った連続読書日数を数える。
  int _consecutiveDays(List<ReadingSession> sessions, DateTime todayDate) {
    final days = <DateTime>{
      for (final session in sessions)
        () {
          final local = session.startedAt.toLocal();
          return DateTime(local.year, local.month, local.day);
        }(),
    };
    if (days.isEmpty) return 0;

    // 今日があればそこから、なければ昨日から遡る。
    var cursor =
        days.contains(todayDate) ? todayDate : todayDate.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;

    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// category → requiredCount → id の順で安定ソートする。
  List<AchievementBadgeDefinition> _sortDefinitions(
    List<AchievementBadgeDefinition> definitions,
  ) {
    // index タイブレークを明示し、List.sort の非安定性に依存しない。
    final indexed = <(AchievementBadgeDefinition, int)>[
      for (var i = 0; i < definitions.length; i++) (definitions[i], i),
    ];
    indexed.sort((a, b) {
      final byCategory = a.$1.category.index.compareTo(b.$1.category.index);
      if (byCategory != 0) return byCategory;
      final byRequired = a.$1.requiredCount.compareTo(b.$1.requiredCount);
      if (byRequired != 0) return byRequired;
      final byId = a.$1.id.compareTo(b.$1.id);
      if (byId != 0) return byId;
      return a.$2.compareTo(b.$2);
    });
    return [for (final entry in indexed) entry.$1];
  }
}
