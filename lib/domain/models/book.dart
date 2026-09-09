import 'reading_status.dart';

/// 書籍モデル
///
/// 書籍情報と読書状態を保持するドメインモデル。
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

  /// 読書状態（積読/読書中/読了）
  final ReadingStatus readingStatus;

  /// 現在の読書ページ（読書中の進捗。読了時は pageCount と一致）
  final int currentPage;

  /// 読了日時（読了状態のときのみ設定される）
  final DateTime? finishedAt;

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
    this.readingStatus = ReadingStatus.unread,
    this.currentPage = 0,
    this.finishedAt,
  });

  /// 読書状態・進捗を更新した新しい [Book] を返す（イミュータブル）。
  Book copyWith({
    ReadingStatus? readingStatus,
    int? currentPage,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
  }) {
    return Book(
      id: id,
      title: title,
      author: author,
      isbn: isbn,
      coverImageUrl: coverImageUrl,
      publisher: publisher,
      publishedDate: publishedDate,
      pageCount: pageCount,
      description: description,
      readingStatus: readingStatus ?? this.readingStatus,
      currentPage: currentPage ?? this.currentPage,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
    );
  }

  /// 読了済みかどうか
  bool get isFinished => readingStatus == ReadingStatus.finished;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Book(id: $id, title: $title)';
}
