import 'package:book_review_app/features/bookshelf/domain/book_deletion.dart';

/// 複数のレビューをまとめて削除する（レビューID指定）
typedef DeleteReviews = Future<void> Function(List<String> reviewIds);

/// 指定書籍に紐づくメモをまとめて削除する（bookId 指定）
typedef DeleteNotesByBookId = Future<void> Function(String bookId);

/// 書籍本体を削除する
typedef DeleteBook = Future<void> Function(String bookId);

/// レビューを1件削除する
typedef DeleteReviewById = Future<void> Function(String reviewId);

/// メモを1件削除する
typedef DeleteNoteById = Future<void> Function(String noteId);

/// 連鎖削除の結果。失敗しても処理は継続し、失敗したステップ名を保持する。
class BookDeletionReport {
  /// 削除できたレビュー件数
  final int deletedReviews;

  /// 削除できたメモ件数
  final int deletedNotes;

  /// 書籍本体を削除できたか
  final bool bookDeleted;

  /// 失敗したステップ名（`reviews` / `notes` / `book` / `review:<id>` など）
  final List<String> failures;

  const BookDeletionReport({
    this.deletedReviews = 0,
    this.deletedNotes = 0,
    this.bookDeleted = false,
    this.failures = const [],
  });

  /// 失敗したステップが1つ以上あるか
  bool get hasFailures => failures.isNotEmpty;

  @override
  String toString() => 'BookDeletionReport(deletedReviews: $deletedReviews, '
      'deletedNotes: $deletedNotes, bookDeleted: $bookDeleted, '
      'failures: $failures)';
}

/// 書籍削除時の連鎖削除サービス。
///
/// ステップ順序は **reviews → notes → book** に固定する。各ステップは個別に
/// try/catch し、失敗しても残りのステップを継続して [BookDeletionReport.failures]
/// に積む。このクラスは決して例外を投げない。
class BookDeletionService {
  /// レビュー一括削除（null ならスキップ）
  final DeleteReviews? deleteReviews;

  /// メモ一括削除（null ならスキップ）
  final DeleteNotesByBookId? deleteNotesByBookId;

  /// 書籍本体の削除（null ならスキップ）
  final DeleteBook? deleteBook;

  /// 孤児レビュー1件削除（null ならスキップ）
  final DeleteReviewById? deleteReviewById;

  /// 孤児メモ1件削除（null ならスキップ）
  final DeleteNoteById? deleteNoteById;

  /// ステップ実行の観測用フック（呼出順の検証に使う）
  final void Function(String step)? onStep;

  const BookDeletionService({
    this.deleteReviews,
    this.deleteNotesByBookId,
    this.deleteBook,
    this.deleteReviewById,
    this.deleteNoteById,
    this.onStep,
  });

  /// 書籍本体と添付データ（レビュー・メモ）を順に削除する。
  ///
  /// 順序は reviews → notes → book。各ステップは独立して失敗を捕捉し、
  /// 失敗しても後続を続行する（本の削除も必ず試みる）。
  ///
  /// [reviewIds] は呼出側が [BookDeletionPlan.build] に用いたレビューID一覧。
  /// [DeleteReviews] はID群を受け取るため、削除対象の実体として渡す。
  Future<BookDeletionReport> deleteBookWithAttachments({
    required String bookId,
    required BookDeletionPlan plan,
    List<String> reviewIds = const [],
  }) async {
    final failures = <String>[];
    var deletedReviews = 0;
    var deletedNotes = 0;
    var bookDeleted = false;

    final removeReviews = deleteReviews;
    if (removeReviews != null && plan.reviewCount > 0) {
      onStep?.call('reviews');
      try {
        await removeReviews(List<String>.unmodifiable(reviewIds));
        deletedReviews = plan.reviewCount;
      } catch (_) {
        failures.add('reviews');
      }
    }

    final removeNotes = deleteNotesByBookId;
    if (removeNotes != null && plan.noteCount > 0) {
      onStep?.call('notes');
      try {
        await removeNotes(bookId);
        deletedNotes = plan.noteCount;
      } catch (_) {
        failures.add('notes');
      }
    }

    final removeBook = deleteBook;
    if (removeBook != null) {
      onStep?.call('book');
      try {
        await removeBook(bookId);
        bookDeleted = true;
      } catch (_) {
        failures.add('book');
      }
    }

    return BookDeletionReport(
      deletedReviews: deletedReviews,
      deletedNotes: deletedNotes,
      bookDeleted: bookDeleted,
      failures: List<String>.unmodifiable(failures),
    );
  }

  /// 孤児レビュー・孤児メモを1件ずつ削除する。
  ///
  /// 1件の失敗で全体を止めず、失敗したIDを failures に積んで継続する。
  Future<BookDeletionReport> deleteOrphans(OrphanData data) async {
    final failures = <String>[];
    var deletedReviews = 0;
    var deletedNotes = 0;

    final removeReview = deleteReviewById;
    if (removeReview != null) {
      for (final review in data.orphanReviews) {
        onStep?.call('review:${review.id}');
        try {
          await removeReview(review.id);
          deletedReviews++;
        } catch (_) {
          failures.add('review:${review.id}');
        }
      }
    }

    final removeNote = deleteNoteById;
    if (removeNote != null) {
      for (final note in data.orphanNotes) {
        onStep?.call('note:${note.id}');
        try {
          await removeNote(note.id);
          deletedNotes++;
        } catch (_) {
          failures.add('note:${note.id}');
        }
      }
    }

    return BookDeletionReport(
      deletedReviews: deletedReviews,
      deletedNotes: deletedNotes,
      bookDeleted: false,
      failures: List<String>.unmodifiable(failures),
    );
  }
}
