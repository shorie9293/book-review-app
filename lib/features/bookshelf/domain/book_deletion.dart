import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';

/// 書籍削除に伴い一緒に消える添付データ（レビュー・メモ）の件数計画。
///
/// UI に「この本の書評3件・メモ5件も一緒に消えます。」と警告するための
/// 純粋な値オブジェクト。副作用は持たない。
class BookDeletionPlan {
  /// 対象書籍に紐づくレビュー件数
  final int reviewCount;

  /// 対象書籍に紐づくメモ件数
  final int noteCount;

  /// 添付なしを表す定数（const 利用のための代表値）
  static const BookDeletionPlan none =
      BookDeletionPlan._(reviewCount: 0, noteCount: 0);

  /// 検証済みの値から生成する const コンストラクタ（内部用）。
  const BookDeletionPlan._(
      {required this.reviewCount, required this.noteCount});

  /// 正の件数から生成する。負値は [ArgumentError]。
  ///
  /// const 本体では例外を投げられないため、検証はこの非 const 本体で行う。
  factory BookDeletionPlan({required int reviewCount, required int noteCount}) {
    if (reviewCount < 0) {
      throw ArgumentError.value(
        reviewCount,
        'reviewCount',
        '件数は 0 以上でなければならない',
      );
    }
    if (noteCount < 0) {
      throw ArgumentError.value(
        noteCount,
        'noteCount',
        '件数は 0 以上でなければならない',
      );
    }
    return BookDeletionPlan._(reviewCount: reviewCount, noteCount: noteCount);
  }

  /// [bookId] に一致するレビュー・メモの件数を数える純粋関数。
  ///
  /// 入力リストは変更しない。
  factory BookDeletionPlan.build({
    required String bookId,
    required List<Review> reviews,
    required List<BookNote> notes,
  }) {
    var reviewCount = 0;
    for (final review in reviews) {
      if (review.bookId == bookId) reviewCount++;
    }
    var noteCount = 0;
    for (final note in notes) {
      if (note.bookId == bookId) noteCount++;
    }
    return BookDeletionPlan._(
      reviewCount: reviewCount,
      noteCount: noteCount,
    );
  }

  /// 一緒に消える添付データの総件数
  int get attachmentCount => reviewCount + noteCount;

  /// 一緒に消える添付データがあるか
  bool get hasAttachments => attachmentCount > 0;

  /// 警告文の末尾（添付なしなら null）。
  ///
  /// 例: 書評3件・メモ5件 → `この本の書評3件・メモ5件も一緒に消えます。`
  /// 例: 書評0件・メモ5件 → `この本のメモ5件も一緒に消えます。`
  String? get warningSuffix {
    if (!hasAttachments) return null;
    final parts = <String>[
      if (reviewCount > 0) '書評$reviewCount件',
      if (noteCount > 0) 'メモ$noteCount件',
    ];
    return 'この本の${parts.join('・')}も一緒に消えます。';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookDeletionPlan &&
          runtimeType == other.runtimeType &&
          reviewCount == other.reviewCount &&
          noteCount == other.noteCount;

  @override
  int get hashCode => Object.hash(reviewCount, noteCount);

  @override
  String toString() =>
      'BookDeletionPlan(reviewCount: $reviewCount, noteCount: $noteCount)';
}

/// 蔵書から参照されなくなった（本の無い）レビュー・メモの集合。
///
/// バックアップは現存する本の添付しか集めないため、孤児データは
/// ここで検出して明示的に掃除する必要がある。
class OrphanData {
  /// 蔵書ID集合に存在しない bookId を持つレビュー（入力順）
  final List<Review> orphanReviews;

  /// 蔵書ID集合に存在しない bookId を持つメモ（入力順）
  final List<BookNote> orphanNotes;

  const OrphanData({
    this.orphanReviews = const [],
    this.orphanNotes = const [],
  });

  /// [books] に存在しない bookId を持つレビュー・メモを抽出する純粋関数。
  ///
  /// 入力順を保ち、入力リストは変更しない。
  factory OrphanData.detect({
    required List<Book> books,
    required List<Review> reviews,
    required List<BookNote> notes,
  }) {
    final bookIds = <String>{for (final book in books) book.id};
    final orphanReviews = <Review>[
      for (final review in reviews)
        if (!bookIds.contains(review.bookId)) review,
    ];
    final orphanNotes = <BookNote>[
      for (final note in notes)
        if (!bookIds.contains(note.bookId)) note,
    ];
    return OrphanData(
      orphanReviews: List<Review>.unmodifiable(orphanReviews),
      orphanNotes: List<BookNote>.unmodifiable(orphanNotes),
    );
  }

  /// 孤児データが1件も無いか
  bool get isEmpty => orphanReviews.isEmpty && orphanNotes.isEmpty;

  /// 孤児データの総件数
  int get total => orphanReviews.length + orphanNotes.length;

  /// 監査表示用のラベル（0件の側も明記する）
  ///
  /// 例: `本の無い書評 3件／メモ 2件`
  String get summaryLabel =>
      '本の無い書評 ${orphanReviews.length}件／メモ ${orphanNotes.length}件';

  @override
  String toString() => 'OrphanData($summaryLabel)';
}
