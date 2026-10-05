/// 1件の推薦（不変・純粋な値オブジェクト）。
class BookRecommendation {
  final String bookId;
  final String title;
  final String author;
  final int score;
  final List<String> matchedGenres;
  final String reason;

  const BookRecommendation({
    required this.bookId,
    required this.title,
    required this.author,
    required this.score,
    this.matchedGenres = const [],
    required this.reason,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookRecommendation && other.bookId == bookId;
  }

  @override
  int get hashCode => bookId.hashCode;
}
