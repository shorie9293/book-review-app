import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/reading/domain/reading_stats.dart';
import 'package:book_review_app/features/share/domain/share_card_data.dart';

/// 読書シェアカードを構築する純粋ロジック。
class ShareCardService {
  /// [books] と [reviews] からシェアカードデータを組み立てる。
  static ShareCardData build({
    required List<Book> books,
    required List<Review> reviews,
    required ReadingStats stats,
    required DateTime now,
  }) {
    ShareCardReview? favorite;
    final candidates = reviews
        .where((r) => r.text.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        if (byRating != 0) return byRating;
        final byCreatedAt = b.createdAt.compareTo(a.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return a.id.compareTo(b.id);
      });
    if (candidates.isNotEmpty) {
      final r = candidates.first;
      final title = books
          .firstWhere(
            (b) => b.id == r.bookId,
            orElse: () => const Book(id: '', title: '無題', author: '', isbn: ''),
          )
          .title;
      favorite = ShareCardReview(
        bookTitle: title,
        rating: r.rating,
        excerpt: normalizeExcerpt(r.text, 40),
      );
    }

    return ShareCardData(
      completedCount:
          books.where((b) => b.readingStatus == ReadingStatus.finished).length,
      unreadCount:
          books.where((b) => b.readingStatus == ReadingStatus.unread).length,
      totalMinutes: stats.totalMinutes,
      activeDays: stats.activeDays,
      favoriteReview: favorite,
      generatedAt: now,
    );
  }

  /// 改行・タブ・連続空白を半角スペース1つに圧縮してtrimする。
  /// [maxLen] 超過時は先頭 [maxLen] 文字 + '…'。
  static String normalizeExcerpt(String text, int maxLen) {
    if (maxLen <= 0) {
      throw ArgumentError.value(maxLen, 'maxLen', 'must be positive');
    }
    final compressed =
        text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compressed.length <= maxLen) return compressed;
    return '${compressed.substring(0, maxLen)}…';
  }

  /// シェア用の複数行テキストを生成する。
  static String shareText(ShareCardData data) {
    final lines = <String>[
      '📚 読書の歩み',
      data.completedLabel,
      '読書時間: ${data.minutesLabel}',
      data.unreadLabel,
    ];
    final fav = data.favoriteReview;
    if (fav != null) {
      lines.add('⭐${fav.rating} 「${fav.excerpt}」〈${fav.bookTitle}〉');
    }
    final y = data.generatedAt.year.toString();
    final m = data.generatedAt.month.toString().padLeft(2, '0');
    final d = data.generatedAt.day.toString().padLeft(2, '0');
    lines.add('$y/$m/$d');
    return lines.join('\n');
  }
}
