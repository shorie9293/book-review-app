import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';

/// バックアップバンドルのスキーマバージョン。
///
/// 復元時の互換性判定に用いる（破壊的変更時のみ増やす）。
const int kBackupSchemaVersion = 1;

/// エクスポート／バックアップの対象データ一式。
///
/// 蔵書・レビュー・読書メモをまとめて持ち、JSON への直列化／復元を担う。
/// ReadingSession（読書セッション）は対象外。
class BackupBundle {
  final int schemaVersion;
  final DateTime exportedAt;
  final List<Book> books;
  final List<Review> reviews;
  final List<BookNote> notes;

  /// [schemaVersion] が1未満は不正（[ArgumentError]）。
  BackupBundle({
    this.schemaVersion = kBackupSchemaVersion,
    required this.exportedAt,
    required this.books,
    required this.reviews,
    required this.notes,
  }) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'must be >= 1',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'books': books.map(_bookToJson).toList(),
        'reviews': reviews.map(_reviewToJson).toList(),
        'notes': notes.map((note) => note.toJson()).toList(),
      };

  /// JSON マップから復元する。
  ///
  /// 必須項目の欠落・型不一致・不正な日付は [FormatException]。
  factory BackupBundle.fromJson(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      throw const FormatException('BackupBundle.schemaVersion is missing');
    }
    final exportedAtRaw = map['exportedAt'];
    if (exportedAtRaw is! String) {
      throw const FormatException('BackupBundle.exportedAt is missing');
    }
    final exportedAt = DateTime.tryParse(exportedAtRaw);
    if (exportedAt == null) {
      throw const FormatException('BackupBundle.exportedAt is invalid');
    }
    return BackupBundle(
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      books: _listOfMaps(map['books']).map(_bookFromJson).toList(),
      reviews: _listOfMaps(map['reviews']).map(_reviewFromJson).toList(),
      notes: _listOfMaps(map['notes']).map(BookNote.fromJson).toList(),
    );
  }

  /// books/reviews/notes の合計件数が0かどうか。
  bool get isEmpty => books.isEmpty && reviews.isEmpty && notes.isEmpty;
}

/// 要素リストの型検証（欠落・非リスト・非マップ要素は [FormatException]）。
List<Map<String, dynamic>> _listOfMaps(Object? raw) {
  if (raw is! List) {
    throw const FormatException('BackupBundle list field is missing');
  }
  return raw.map((item) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('BackupBundle list element is invalid');
    }
    return item;
  }).toList();
}

/// Book の JSON 直列化（HiveBookRepository._bookToJson と同型）。
Map<String, dynamic> _bookToJson(Book book) => {
      'id': book.id,
      'title': book.title,
      'author': book.author,
      'isbn': book.isbn,
      'coverImageUrl': book.coverImageUrl,
      'publisher': book.publisher,
      'publishedDate': book.publishedDate,
      'pageCount': book.pageCount,
      'description': book.description,
      'genres': book.genres,
      'readingStatus': book.readingStatus.name,
      'currentPage': book.currentPage,
      'finishedAt': book.finishedAt?.toIso8601String(),
      'addedAt': book.addedAt?.toIso8601String(),
    };

/// Book の JSON 復元（欠落・型不一致・不正日付は [FormatException]）。
Book _bookFromJson(Map<String, dynamic> map) {
  final id = map['id'];
  final title = map['title'];
  final author = map['author'];
  final isbn = map['isbn'];
  if (id is! String) {
    throw const FormatException('Book.id is missing');
  }
  if (title is! String) {
    throw const FormatException('Book.title is missing');
  }
  if (author is! String) {
    throw const FormatException('Book.author is missing');
  }
  if (isbn is! String) {
    throw const FormatException('Book.isbn is missing');
  }

  final currentPage = map['currentPage'];
  if (currentPage != null && currentPage is! int) {
    throw const FormatException('Book.currentPage is invalid');
  }

  final pageCount = map['pageCount'];
  if (pageCount != null && pageCount is! int) {
    throw const FormatException('Book.pageCount is invalid');
  }

  final genresRaw = map['genres'];
  final genres = <String>[];
  if (genresRaw is List) {
    for (final genre in genresRaw) {
      if (genre is String) genres.add(genre);
    }
  }

  final finishedAt = _parseOptionalDate(map['finishedAt'], 'Book.finishedAt');
  final addedAt = _parseOptionalDate(map['addedAt'], 'Book.addedAt');

  return Book(
    id: id,
    title: title,
    author: author,
    isbn: isbn,
    coverImageUrl: _optionalString(map['coverImageUrl']),
    publisher: _optionalString(map['publisher']),
    publishedDate: _optionalString(map['publishedDate']),
    description: _optionalString(map['description']),
    genres: genres,
    readingStatus: ReadingStatus.fromStorage(map['readingStatus']),
    currentPage: currentPage as int? ?? 0,
    pageCount: pageCount as int?,
    finishedAt: finishedAt,
    addedAt: addedAt,
  );
}

/// Review の JSON 直列化（HiveReviewRepository._reviewToJson と同型）。
Map<String, dynamic> _reviewToJson(Review review) => {
      'id': review.id,
      'bookId': review.bookId,
      'rating': review.rating,
      'text': review.text,
      'createdAt': review.createdAt.toIso8601String(),
      'updatedAt': review.updatedAt.toIso8601String(),
    };

/// Review の JSON 復元（欠落・型不一致・不正日付は [FormatException]）。
Review _reviewFromJson(Map<String, dynamic> map) {
  final id = map['id'];
  final bookId = map['bookId'];
  final rating = map['rating'];
  final text = map['text'];
  if (id is! String) {
    throw const FormatException('Review.id is missing');
  }
  if (bookId is! String) {
    throw const FormatException('Review.bookId is missing');
  }
  if (rating is! int) {
    throw const FormatException('Review.rating is missing');
  }
  if (text is! String) {
    throw const FormatException('Review.text is missing');
  }
  final createdAt = _parseRequiredDate(map['createdAt'], 'Review.createdAt');
  final updatedAt =
      map['updatedAt'] == null ? createdAt : _parseRequiredDate(map['updatedAt'], 'Review.updatedAt');
  return Review(
    id: id,
    bookId: bookId,
    rating: rating,
    text: text,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

String? _optionalString(Object? value) => value is String ? value : null;

DateTime? _parseOptionalDate(Object? raw, String field) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse('$raw');
  if (parsed == null) {
    throw FormatException('$field is invalid');
  }
  return parsed;
}

DateTime _parseRequiredDate(Object? raw, String field) {
  final parsed = DateTime.tryParse('$raw');
  if (parsed == null) {
    throw FormatException('$field is invalid');
  }
  return parsed;
}

/// バックアップ対象件数の要約（画面表示用）。
class BackupSummary {
  final int books;
  final int reviews;
  final int notes;

  const BackupSummary({
    required this.books,
    required this.reviews,
    required this.notes,
  });

  factory BackupSummary.of(BackupBundle b) => BackupSummary(
        books: b.books.length,
        reviews: b.reviews.length,
        notes: b.notes.length,
      );

  int get total => books + reviews + notes;

  /// 例: 「蔵書 3冊 / レビュー 2件 / メモ 5件」
  String get label => '蔵書 ${books}冊 / レビュー ${reviews}件 / メモ ${notes}件';
}

/// リストア（マージ）結果の件数集計。
///
/// 既存id は上書きせずスキップするため、
/// skipped = incoming総数（重複畳み込み後） - added。
class BackupMergeResult {
  final int booksAdded;
  final int reviewsAdded;
  final int notesAdded;
  final int booksSkipped;
  final int reviewsSkipped;
  final int notesSkipped;

  const BackupMergeResult({
    required this.booksAdded,
    required this.reviewsAdded,
    required this.notesAdded,
    required this.booksSkipped,
    required this.reviewsSkipped,
    required this.notesSkipped,
  });

  int get totalAdded => booksAdded + reviewsAdded + notesAdded;

  int get totalSkipped => booksSkipped + reviewsSkipped + notesSkipped;

  /// 追加が1件も無かったかどうか。
  bool get isEmpty => totalAdded == 0;
}
