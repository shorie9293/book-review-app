/// 書籍モデル
///
/// 書籍情報を保持するドメインモデル。
/// 同一性は `id` に基づく（ISBNではなくデータベースID）。
class Book {
  final String id;
  final String title;
  final String author;
  final String isbn;
  final String? coverImageUrl;
  final String? publisher;
  final String? publishedDate;
  final int? pageCount;
  final String? description;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    this.coverImageUrl,
    this.publisher,
    this.publishedDate,
    this.pageCount,
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Book(id: $id, title: $title)';
}
