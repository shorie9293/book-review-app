import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';

import 'book_recommendation.dart';

/// 読書傾向から「次に読む一冊」を推薦する純粋関数を提供する。
class RecommendationService {
  RecommendationService._();

  static const int defaultLimit = 5;

  /// 読書傾向から「次に読む一冊」を推薦する純粋関数。
  static List<BookRecommendation> recommend({
    required List<Book> books,
    required List<Review> reviews,
    int limit = defaultLimit,
  }) {
    try {
      if (limit <= 0) return const [];
      final candidates = books
          .where((b) => b.readingStatus != ReadingStatus.finished)
          .toList();
      if (candidates.isEmpty) return const [];

      final genrePrefs = <String>{};
      final authorPrefs = <String>{};

      void absorb(Book b) {
        for (final g in b.genres) {
          genrePrefs.add(g.trim());
        }
        authorPrefs.add(b.author.trim());
      }

      for (final b in books) {
        if (b.readingStatus == ReadingStatus.finished) absorb(b);
      }
      final bookById = {for (final b in books) b.id: b};
      for (final r in reviews) {
        if (r.rating >= 4) {
          final target = bookById[r.bookId];
          if (target != null) absorb(target);
        }
      }

      final scored = <(Book, int, List<String>, bool)>[];
      for (final c in candidates) {
        final trimmedGenres = c.genres.map((g) => g.trim()).toSet();
        final matched = genrePrefs
            .where((g) => trimmedGenres.contains(g))
            .toSet()
            .toList()
          ..sort();
        final authorMatch = authorPrefs.contains(c.author.trim());
        var score = matched.length * 3;
        if (authorMatch) score += 5;
        if (c.readingStatus == ReadingStatus.reading) score += 2;
        scored.add((c, score, matched, authorMatch));
      }

      scored.sort((a, b) {
        final byScore = b.$2.compareTo(a.$2);
        if (byScore != 0) return byScore;
        final byTitle = a.$1.title.compareTo(b.$1.title);
        if (byTitle != 0) return byTitle;
        return a.$1.id.compareTo(b.$1.id);
      });

      final take = scored.length < limit ? scored.length : limit;
      final result = <BookRecommendation>[];
      for (var i = 0; i < take; i++) {
        final (c, score, matched, authorMatch) = scored[i];
        result.add(BookRecommendation(
          bookId: c.id,
          title: c.title,
          author: c.author,
          score: score,
          matchedGenres: matched.isEmpty ? const [] : matched,
          reason: _reason(c, matched, authorMatch),
        ));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  static String _reason(Book c, List<String> matched, bool authorMatch) {
    if (authorMatch && matched.isNotEmpty) {
      return '好きな著者「${c.author}」・ジャンル「${matched.first}」';
    }
    if (authorMatch) return '好きな著者「${c.author}」';
    if (matched.isNotEmpty) return '好きなジャンル「${matched.first}」';
    return '積読を消化しましょう';
  }
}
