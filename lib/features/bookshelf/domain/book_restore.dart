import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';

/// 蔵書削除を取り消すときの復元ステップ。
///
/// 削除は `reviews → notes → book` の順なので、復元はその**逆順**になる。
enum BookRestoreStep {
  /// 書籍本体を戻す
  book,

  /// 書籍に紐づくメモを戻す
  notes,

  /// 書籍に紐づくレビューを戻す
  reviews,
}

/// 蔵書復元の実行順序を宣言的に固定する計画値。
///
/// 順序は [steps] に `book → notes → reviews`（削除順の逆順）として
/// ハードコードされており、呼出側が並べ替える余地はない。
/// 復元サービスは必ずこの宣言に従う。
class BookRestorePlan {
  const BookRestorePlan._();

  /// 復元ステップの固定順序（削除順 reviews → notes → book の逆順）。
  ///
  /// 呼出側で並べ替え不可（[List.unmodifiable] 相当の const リスト）。
  static const List<BookRestoreStep> steps = <BookRestoreStep>[
    BookRestoreStep.book,
    BookRestoreStep.notes,
    BookRestoreStep.reviews,
  ];

  /// ステップ名の固定順序（観測・報告用）。例: `['book', 'notes', 'reviews']`
  static const List<String> stepNames = <String>['book', 'notes', 'reviews'];

  /// 削除順（reviews → notes → book）を復元順へ反転したもの。
  ///
  /// 削除側の宣言から復元順を導けることの保証用。結果は
  /// `['book', 'notes', 'reviews']` に一致する。
  static List<String> reverseOfDeletionOrder(List<String> deletionOrder) {
    return List<String>.unmodifiable(deletionOrder.reversed);
  }

  @override
  String toString() => 'BookRestorePlan($stepNames)';
}

/// 蔵書削除の直前スナップショット（復元の材料）。
///
/// 削除処理へ渡す前に、消える実体（本・レビュー・メモ）をそのまま保持する。
/// ID が空の実体は復元先を特定できないため [ArgumentError] で拒否する。
/// const 本体では例外を投げられないため、検証はこの非 const 本体で行う。
class BookRestoreSnapshot {
  /// 削除された書籍
  final Book book;

  /// 削除されたレビュー（書籍に紐づくもののみ）
  final List<Review> reviews;

  /// 削除されたメモ（書籍に紐づくもののみ）
  final List<BookNote> notes;

  BookRestoreSnapshot({
    required this.book,
    List<Review> reviews = const [],
    List<BookNote> notes = const [],
  })  : reviews = List<Review>.unmodifiable(reviews),
        notes = List<BookNote>.unmodifiable(notes) {
    if (book.id.isEmpty) {
      throw ArgumentError.value(book.id, 'book.id', '書籍IDが空では復元できない');
    }
    for (final review in reviews) {
      if (review.id.isEmpty) {
        throw ArgumentError.value(review.id, 'reviews[].id', 'レビューIDが空');
      }
    }
    for (final note in notes) {
      if (note.id.isEmpty) {
        throw ArgumentError.value(note.id, 'notes[].id', 'メモIDが空では復元できない');
      }
    }
  }

  /// [book] に紐づく添付だけを取り込んだスナップショットを作る。
  ///
  /// 引数のリストに他書籍のレビュー・メモが混ざっていても、`bookId` が
  /// 一致するものだけを保持する（巻き込み復元の防止）。入力は変更しない。
  factory BookRestoreSnapshot.capture({
    required Book book,
    required List<Review> reviews,
    required List<BookNote> notes,
  }) {
    return BookRestoreSnapshot(
      book: book,
      reviews: <Review>[
        for (final review in reviews)
          if (review.bookId == book.id) review,
      ],
      notes: <BookNote>[
        for (final note in notes)
          if (note.bookId == book.id) note,
      ],
    );
  }

  /// 対象書籍ID
  String get bookId => book.id;

  /// 復元すべき添付データの総件数
  int get attachmentCount => reviews.length + notes.length;

  /// 添付データが1件も無いか
  bool get hasAttachments => attachmentCount > 0;

  @override
  String toString() => 'BookRestoreSnapshot(bookId: $bookId, '
      'reviews: ${reviews.length}, notes: ${notes.length})';
}
