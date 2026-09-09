import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/reading_status_service.dart';

void main() {
  Book sample({int? pageCount = 300}) => Book(
        id: 'b1',
        title: 'テスト駆動開発',
        author: 'Kent Beck',
        isbn: '978-4-274-21788-3',
        pageCount: pageCount,
      );

  group('ReadingStatusService', () {
    test('markStarted は読書中に遷移し読了日を消す', () {
      final book = sample().copyWith(
        readingStatus: ReadingStatus.finished,
        currentPage: 300,
        finishedAt: DateTime(2026, 1, 1),
      );
      final updated = ReadingStatusService.markStarted(book);

      expect(updated.readingStatus, ReadingStatus.reading);
      expect(updated.finishedAt, isNull);
      expect(updated.currentPage, 300); // 進捗は保持
    });

    test('markUnread は積読に戻し進捗と読了日をクリアする', () {
      final book = sample().copyWith(
        readingStatus: ReadingStatus.finished,
        currentPage: 300,
        finishedAt: DateTime(2026, 1, 1),
      );
      final updated = ReadingStatusService.markUnread(book);

      expect(updated.readingStatus, ReadingStatus.unread);
      expect(updated.currentPage, 0);
      expect(updated.finishedAt, isNull);
    });

    test('updateProgress は読書中を維持してページを更新する', () {
      final book = sample().copyWith(readingStatus: ReadingStatus.reading);
      final updated = ReadingStatusService.updateProgress(book, 120);

      expect(updated.readingStatus, ReadingStatus.reading);
      expect(updated.currentPage, 120);
      expect(updated.finishedAt, isNull);
    });

    test('updateProgress で pageCount に達すると読了に遷移する', () {
      final book = sample().copyWith(readingStatus: ReadingStatus.reading);
      final updated = ReadingStatusService.updateProgress(book, 300);

      expect(updated.readingStatus, ReadingStatus.finished);
      expect(updated.currentPage, 300);
      expect(updated.finishedAt, isNotNull);
    });

    test('updateProgress の負値は 0 にクランプされる', () {
      final book = sample();
      final updated = ReadingStatusService.updateProgress(book, -5);

      expect(updated.currentPage, 0);
      expect(updated.readingStatus, ReadingStatus.reading);
    });

    test('markFinished は読了に遷移し読了日を記録する', () {
      final book = sample().copyWith(
        readingStatus: ReadingStatus.reading,
        currentPage: 200,
      );
      final updated = ReadingStatusService.markFinished(book);

      expect(updated.readingStatus, ReadingStatus.finished);
      expect(updated.currentPage, 300);
      expect(updated.finishedAt, isNotNull);
    });

    test('setFinishedAt は読了状態を保って日時を補正する', () {
      final book = sample().copyWith(
        readingStatus: ReadingStatus.finished,
        currentPage: 300,
        finishedAt: DateTime(2026, 1, 1),
      );
      final updated =
          ReadingStatusService.setFinishedAt(book, DateTime(2026, 6, 1));

      expect(updated.readingStatus, ReadingStatus.finished);
      expect(updated.finishedAt, DateTime(2026, 6, 1));
    });

    test('setFinishedAt は未読了の本を読了に遷移させる', () {
      final book = sample();
      final updated =
          ReadingStatusService.setFinishedAt(book, DateTime(2026, 6, 1));

      expect(updated.readingStatus, ReadingStatus.finished);
      expect(updated.finishedAt, DateTime(2026, 6, 1));
    });

    test('pageCount が無い本の markFinished は現在ページを保持する', () {
      final book = Book(
        id: 'nopage',
        title: 'ページ数不明',
        author: 'A',
        isbn: 'i',
      ).copyWith(readingStatus: ReadingStatus.reading, currentPage: 10);
      final updated = ReadingStatusService.markFinished(book);

      expect(updated.currentPage, 10);
      expect(updated.finishedAt, isNotNull);
    });

    test('copyWith は clearFinishedAt で読了日を明示的に消せる', () {
      final book = sample().copyWith(finishedAt: DateTime(2026, 1, 1));
      final cleared = book.copyWith(clearFinishedAt: true);

      expect(cleared.finishedAt, isNull);
      expect(book.finishedAt, isNotNull); // 元は不変
    });
  });
}
