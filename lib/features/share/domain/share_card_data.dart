/// シェアカードに載せる1件のレビュー抜粋。
class ShareCardReview {
  final String bookTitle;
  final int rating;
  final String excerpt;

  ShareCardReview({
    required String bookTitle,
    required this.rating,
    required String excerpt,
  })  : bookTitle = bookTitle.trim().isEmpty ? '無題' : bookTitle,
        excerpt = excerpt.trim() {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'must be 1..5');
    }
  }
}

/// 読書シェアカードのデータ（不変・純粋な値オブジェクト）。
class ShareCardData {
  /// 読了冊数
  final int completedCount;

  /// 積読冊数
  final int unreadCount;

  /// 総読書時間(分)
  final int totalMinutes;

  /// 読書セッションのある日数
  final int activeDays;

  /// 最高評価レビュー（無ければnull）
  final ShareCardReview? favoriteReview;

  final DateTime generatedAt;

  ShareCardData({
    required this.completedCount,
    required this.unreadCount,
    required this.totalMinutes,
    required this.activeDays,
    required this.favoriteReview,
    required this.generatedAt,
  }) {
    if (completedCount < 0) {
      throw ArgumentError.value(completedCount, 'completedCount');
    }
    if (unreadCount < 0) {
      throw ArgumentError.value(unreadCount, 'unreadCount');
    }
    if (totalMinutes < 0) {
      throw ArgumentError.value(totalMinutes, 'totalMinutes');
    }
    if (activeDays < 0) {
      throw ArgumentError.value(activeDays, 'activeDays');
    }
  }

  String get completedLabel => '読了 $completedCount冊';

  String get unreadLabel => '積読 $unreadCount冊';

  /// 総読書時間ラベル（ReadingStats.totalLabel と同じ書式）。
  String get minutesLabel {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes分';
    if (minutes == 0) return '$hours時間';
    return '$hours時間$minutes分';
  }
}
