/// 書籍レビューモデル
///
/// ユーザーが書籍に対して残すレビュー情報を保持する。
/// レーティングは1〜5の範囲でクランプされる。
/// 同一性は `id` に基づく。
class Review {
  final String id;
  final String bookId;
  final int rating;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review({
    required this.id,
    required this.bookId,
    required int rating,
    required this.text,
    required this.createdAt,
    DateTime? updatedAt,
  })  : rating = rating.clamp(1, 5),
        updatedAt = updatedAt ?? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Review && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Review(id: $id, bookId: $bookId, rating: $rating)';
}
