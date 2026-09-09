import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';

/// 読書状態遷移の純粋ロジック
///
/// 蔵書の読書状態（積読/読書中/読了）と進捗ページ・読了日を
/// イミュータブルな遷移ルールで管理する。副作用は持たない。
abstract class ReadingStatusService {
  /// 読書開始を記録する（読了→積読への巻き戻しも許可）。
  ///
  /// [currentPage] は前回の進捗を保持する。
  static Book markStarted(Book book) {
    return book.copyWith(
      readingStatus: ReadingStatus.reading,
      clearFinishedAt: true,
    );
  }

  /// 読書を積読（未読）に戻す。
  static Book markUnread(Book book) {
    return book.copyWith(
      readingStatus: ReadingStatus.unread,
      currentPage: 0,
      clearFinishedAt: true,
    );
  }

  /// 現在ページを更新する（読書中状態を維持、負値は 0 にクランプ）。
  ///
  /// [page] が本の総ページ [pageCount] 以上なら読了扱いに遷移し、
  /// 読了日時を記録する。
  static Book updateProgress(Book book, int page) {
    final clamped = page < 0 ? 0 : page;
    final pageCount = book.pageCount;
    if (pageCount != null && clamped >= pageCount) {
      return book.copyWith(
        readingStatus: ReadingStatus.finished,
        currentPage: pageCount,
        finishedAt: DateTime.now(),
      );
    }
    return book.copyWith(
      readingStatus: ReadingStatus.reading,
      currentPage: clamped,
    );
  }

  /// 読了を記録する（読了日時を今に設定、総ページまで進める）。
  static Book markFinished(Book book) {
    final pageCount = book.pageCount;
    return book.copyWith(
      readingStatus: ReadingStatus.finished,
      currentPage: pageCount ?? book.currentPage,
      finishedAt: DateTime.now(),
    );
  }

  /// 読了日時の手動設定（読了状態の本の日付を補正する際に使用）。
  static Book setFinishedAt(Book book, DateTime finishedAt) {
    if (book.isFinished) {
      return book.copyWith(finishedAt: finishedAt);
    }
    return book.copyWith(
      readingStatus: ReadingStatus.finished,
      finishedAt: finishedAt,
    );
  }
}
