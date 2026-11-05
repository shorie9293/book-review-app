import 'package:flutter/foundation.dart';

import 'package:book_review_app/domain/models/review.dart';

/// レビュー横断検索の検索条件（不変）
///
/// すべての条件は AND で結合される。null / 空 は「絞り込まない」を意味する。
@immutable
class ReviewQuery {
  /// 検索語（空白区切りは AND）
  final String text;

  /// 特定の本に絞る。null なら全件
  final String? bookId;

  /// 評価の下限（この値以上）。null なら評価で絞らない
  final int? minRating;

  /// 作成日の期間・開始（両端を含む）。null なら下限なし
  final DateTime? from;

  /// 作成日の期間・終了（両端を含む）。null なら上限なし
  final DateTime? to;

  const ReviewQuery({
    this.text = '',
    this.bookId,
    this.minRating,
    this.from,
    this.to,
  });

  ReviewQuery copyWith({
    String? text,
    String? bookId,
    int? minRating,
    DateTime? from,
    DateTime? to,
    bool clearBookId = false,
    bool clearMinRating = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return ReviewQuery(
      text: text ?? this.text,
      bookId: clearBookId ? null : (bookId ?? this.bookId),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReviewQuery &&
        other.text == text &&
        other.bookId == bookId &&
        other.minRating == minRating &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(text, bookId, minRating, from, to);
}

/// 検索結果の1件（レビュー本体 + 表示用の書名）
///
/// 同一性は [Review.id] に基づく。
@immutable
class ReviewSearchResult {
  final Review review;

  /// 書名。書籍が見つからない場合は null
  final String? bookTitle;

  const ReviewSearchResult({required this.review, this.bookTitle});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewSearchResult && other.review.id == review.id);

  @override
  int get hashCode => review.id.hashCode;

  @override
  String toString() =>
      'ReviewSearchResult(id: ${review.id}, bookTitle: $bookTitle)';
}

/// レビューの横断検索（純粋関数のみ・I/O なし・現在時刻を参照しない）
class ReviewQueryService {
  const ReviewQueryService._();

  /// 検索語の正規化:
  /// trim → 全角英数字(U+FF01..U+FF5E)と全角スペース(U+3000)を半角へ
  /// → toLowerCase → 連続空白を単一化
  static String normalize(String input) {
    final sb = StringBuffer();
    for (final code in input.trim().runes) {
      if (code >= 0xFF01 && code <= 0xFF5E) {
        sb.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3000) {
        sb.write(' ');
      } else {
        sb.writeCharCode(code);
      }
    }
    return sb.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 検索語を [Review.text] か書名に含むか（正規化後の部分一致）。
  ///
  /// 空白区切りの複数語は AND（すべての語がいずれかの対象に含まれること）。
  /// 空/空白のみの検索語なら常に true。
  static bool matchesText(Review review, String? bookTitle, String text) {
    final q = normalize(text);
    if (q.isEmpty) return true;
    final body = normalize(review.text);
    final title = normalize(bookTitle ?? '');
    for (final term in q.split(' ')) {
      if (term.isEmpty) continue;
      if (!body.contains(term) && !title.contains(term)) return false;
    }
    return true;
  }

  /// 条件を適用し、createdAt 降順（同時刻は id 昇順）で安定ソートした結果を返す。
  ///
  /// [reviews] は破壊しない。
  static List<ReviewSearchResult> apply(
    List<Review> reviews,
    Map<String, String> bookTitles,
    ReviewQuery query,
  ) {
    final filtered = reviews.where((r) {
      if (!matchesText(r, bookTitles[r.bookId], query.text)) return false;
      if (query.bookId != null && r.bookId != query.bookId) return false;
      if (query.minRating != null && r.rating < query.minRating!) return false;
      final from = query.from;
      if (from != null && r.createdAt.isBefore(from)) return false;
      final to = query.to;
      if (to != null && r.createdAt.isAfter(to)) return false;
      return true;
    }).map((r) => ReviewSearchResult(
          review: r,
          bookTitle: bookTitles[r.bookId],
        ));

    final result = List<ReviewSearchResult>.of(filtered);
    result.sort((a, b) {
      final byDate = b.review.createdAt.compareTo(a.review.createdAt);
      if (byDate != 0) return byDate;
      return a.review.id.compareTo(b.review.id);
    });
    return result;
  }

  /// 本文の抜粋。
  ///
  /// 改行・連続空白を単一空白へ畳み、[maxLength] を超える場合は
  /// 末尾を '…' に置き換える（戻り値の長さは maxLength 以内）。
  /// [maxLength] が 0 以下なら空文字。
  static String excerpt(String text, {int maxLength = 80}) {
    if (maxLength <= 0) return '';
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final runes = collapsed.runes.toList();
    if (runes.length <= maxLength) return collapsed;
    return '${String.fromCharCodes(runes.take(maxLength - 1))}…';
  }
}
