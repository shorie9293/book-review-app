import 'dart:async';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/domain/book_restore.dart';

/// 書籍を戻す（null ならスキップ）
typedef RestoreBook = Future<void> Function(Book book);

/// メモを1件戻す（null ならスキップ）
typedef RestoreNote = Future<void> Function(BookNote note);

/// レビューを1件戻す（null ならスキップ）
typedef RestoreReview = Future<void> Function(Review review);

/// 連鎖復元の結果。失敗しても処理は継続し、失敗したステップ名を保持する。
class BookRestoreReport {
  /// 復元できたレビュー件数
  final int restoredReviews;

  /// 復元できたメモ件数
  final int restoredNotes;

  /// 書籍本体を復元できたか
  final bool bookRestored;

  /// 失敗したステップ名（`book` / `notes` / `reviews` / `note:<id>` など）
  final List<String> failures;

  const BookRestoreReport({
    this.restoredReviews = 0,
    this.restoredNotes = 0,
    this.bookRestored = false,
    this.failures = const [],
  });

  /// 失敗したステップが1つ以上あるか
  bool get hasFailures => failures.isNotEmpty;

  /// 復元できた総件数（書籍本体を含む）
  int get restoredTotal =>
      restoredReviews + restoredNotes + (bookRestored ? 1 : 0);

  @override
  String toString() => 'BookRestoreReport(restoredReviews: $restoredReviews, '
      'restoredNotes: $restoredNotes, bookRestored: $bookRestored, '
      'failures: $failures)';
}

/// 蔵書削除を取り消す連鎖復元サービス。
///
/// ステップ順序は [BookRestorePlan.steps] が宣言する
/// **book → notes → reviews**（削除順 reviews → notes → book の逆順）に固定。
/// 各ステップ・各要素は個別に try/catch し、失敗しても残りを継続して
/// [BookRestoreReport.failures] に積む。このクラスは決して例外を投げない。
class BookRestoreService {
  /// 書籍本体の復元（null ならスキップ）
  final RestoreBook? addBook;

  /// メモ1件の復元（null ならスキップ）
  final RestoreNote? addNote;

  /// レビュー1件の復元（null ならスキップ）
  final RestoreReview? addReview;

  /// ステップ実行の観測用フック（呼出順の検証に使う）
  final void Function(String step)? onStep;

  const BookRestoreService({
    this.addBook,
    this.addNote,
    this.addReview,
    this.onStep,
  });

  /// [snapshot] を逆順（book → notes → reviews）に復元する。
  ///
  /// 各ステップは独立して失敗を捕捉し、失敗しても後続を続行する。
  /// 注入されていないステップ（null）はそのままスキップする。
  Future<BookRestoreReport> restore(BookRestoreSnapshot snapshot) async {
    final failures = <String>[];
    var restoredReviews = 0;
    var restoredNotes = 0;
    var bookRestored = false;

    for (final step in BookRestorePlan.steps) {
      switch (step) {
        case BookRestoreStep.book:
          final restoreBook = addBook;
          if (restoreBook == null) break;
          onStep?.call(BookRestoreStep.book.name);
          try {
            await restoreBook(snapshot.book);
            bookRestored = true;
          } catch (_) {
            failures.add(BookRestoreStep.book.name);
          }
          break;

        case BookRestoreStep.notes:
          final restoreNote = addNote;
          if (restoreNote == null || snapshot.notes.isEmpty) break;
          onStep?.call(BookRestoreStep.notes.name);
          for (final note in snapshot.notes) {
            try {
              await restoreNote(note);
              restoredNotes++;
            } catch (_) {
              failures.add('note:${note.id}');
            }
          }
          break;

        case BookRestoreStep.reviews:
          final restoreReview = addReview;
          if (restoreReview == null || snapshot.reviews.isEmpty) break;
          onStep?.call(BookRestoreStep.reviews.name);
          for (final review in snapshot.reviews) {
            try {
              await restoreReview(review);
              restoredReviews++;
            } catch (_) {
              failures.add('review:${review.id}');
            }
          }
          break;
      }
    }

    return BookRestoreReport(
      restoredReviews: restoredReviews,
      restoredNotes: restoredNotes,
      bookRestored: bookRestored,
      failures: List<String>.unmodifiable(failures),
    );
  }

  /// [restore] を専用 zone に隔離して実行する。
  ///
  /// 復元中に飛んだ想定外の非同期例外が呼出元の zone（Flutter の
  /// エラー報告経路）へ漏れないよう `runZonedGuarded` で包む。zone が
  /// 例外を捕まえた場合も [BookRestoreReport] に載せて返し、投げない。
  Future<BookRestoreReport> restoreInIsolatedZone(
    BookRestoreSnapshot snapshot,
  ) async {
    final completer = Completer<BookRestoreReport>();
    void finish(BookRestoreReport report) {
      if (!completer.isCompleted) completer.complete(report);
    }

    runZonedGuarded(
      () async {
        try {
          finish(await restore(snapshot));
        } catch (_) {
          finish(const BookRestoreReport(failures: <String>['unexpected']));
        }
      },
      (error, stackTrace) =>
          finish(const BookRestoreReport(failures: <String>['unexpected'])),
    );

    return completer.future;
  }
}
