import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';

void main() {
  Book book({
    ReadingStatus status = ReadingStatus.unread,
    int currentPage = 0,
    int? pageCount = 300,
    DateTime? finishedAt,
  }) =>
      Book(
        id: 'b1',
        title: 'テスト駆動開発',
        author: 'Kent Beck',
        isbn: '978-4-274-21788-3',
        pageCount: pageCount,
        readingStatus: status,
        currentPage: currentPage,
        finishedAt: finishedAt,
      );

  Review review(
    String id, {
    int rating = 3,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Review(
        id: id,
        bookId: 'b1',
        rating: rating,
        text: 'レビュー$id',
        createdAt: createdAt ?? DateTime(2026, 1, 1),
        updatedAt: updatedAt,
      );

  BookNote note(
    String id, {
    NoteKind kind = NoteKind.memo,
    bool isFavorite = false,
    int? pageNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      BookNote(
        id: id,
        bookId: 'b1',
        kind: kind,
        content: '内容$id',
        pageNumber: pageNumber,
        createdAt: createdAt ?? DateTime(2026, 1, 1),
        updatedAt: updatedAt,
        isFavorite: isFavorite,
      );

  group('BookDetailSummary.reviewCount / counts', () {
    test('レビュー・メモが空なら全カウント0', () {
      final s = BookDetailSummary.build(book(), [], []);
      expect(s.reviewCount, 0);
      expect(s.averageRating, isNull);
      expect(s.favoriteNoteCount, 0);
      expect(s.memoCount, 0);
      expect(s.quoteCount, 0);
      expect(s.lastActivityAt, isNull);
    });

    test('レビュー2件・メモ3件（メモ2/引用1・お気に入り1）のカウント', () {
      final s = BookDetailSummary.build(book(), [
        review('r1', rating: 4),
        review('r2', rating: 2),
      ], [
        note('n1', kind: NoteKind.memo),
        note('n2', kind: NoteKind.quote, isFavorite: true),
        note('n3', kind: NoteKind.memo, isFavorite: true),
      ]);
      expect(s.reviewCount, 2);
      expect(s.favoriteNoteCount, 2);
      expect(s.memoCount, 2);
      expect(s.quoteCount, 1);
    });
  });

  group('BookDetailSummary.averageRating', () {
    test('レビュー1件はそのrating（整数）', () {
      final s = BookDetailSummary.build(book(), [review('r1', rating: 4)], []);
      expect(s.averageRating, 4);
    });

    test('平均は1桁目で丸められる（3.66→3.7）', () {
      final s = BookDetailSummary.build(book(), [
        review('r1', rating: 3),
        review('r2', rating: 4),
        review('r3', rating: 4),
      ], []);
      expect(s.averageRating, 3.7);
    });

    test('レビュー0件はnull（0除算ガード）', () {
      final s = BookDetailSummary.build(book(), const [], const []);
      expect(s.averageRating, isNull);
    });
  });

  group('BookDetailSummary.lastActivityAt', () {
    test('reviewsとnotesのupdatedAtの最大値', () {
      final s = BookDetailSummary.build(book(), [
        review('r1', updatedAt: DateTime(2026, 3, 1)),
        review('r2', updatedAt: DateTime(2026, 2, 1)),
      ], [
        note('n1', updatedAt: DateTime(2026, 5, 1)),
      ]);
      expect(s.lastActivityAt, DateTime(2026, 5, 1));
    });

    test('reviewsのみの場合はその最大', () {
      final s = BookDetailSummary.build(book(), [
        review('r1', updatedAt: DateTime(2026, 3, 1)),
      ], []);
      expect(s.lastActivityAt, DateTime(2026, 3, 1));
    });

    test('notesのみの場合はその最大', () {
      final s = BookDetailSummary.build(book(), [], [
        note('n1', updatedAt: DateTime(2026, 4, 1)),
      ]);
      expect(s.lastActivityAt, DateTime(2026, 4, 1));
    });

    test('両方空はnull', () {
      final s = BookDetailSummary.build(book(), [], []);
      expect(s.lastActivityAt, isNull);
    });
  });

  group('BookDetailSummary.progressLabel', () {
    test('未読は「未読」', () {
      final s = BookDetailSummary.build(
        book(status: ReadingStatus.unread),
        [],
        [],
      );
      expect(s.progressLabel, '未読');
    });

    test('読書中はラベル+ページ形式', () {
      final s = BookDetailSummary.build(
        book(status: ReadingStatus.reading, currentPage: 12, pageCount: 300),
        [],
        [],
      );
      expect(s.progressLabel, '読書中 12/300ページ');
    });

    test('読了はラベル+読了日', () {
      final s = BookDetailSummary.build(
        book(
          status: ReadingStatus.finished,
          finishedAt: DateTime(2026, 2, 14),
        ),
        [],
        [],
      );
      expect(s.progressLabel, '読了 2026/02/14');
    });

    test('読書中でpageCountがnullならページ形式なし', () {
      final s = BookDetailSummary.build(
        book(status: ReadingStatus.reading, currentPage: 5, pageCount: null),
        [],
        [],
      );
      expect(s.progressLabel, '読書中');
    });

    test('読了でfinishedAtがnullならラベルのみ', () {
      final s = BookDetailSummary.build(
        book(status: ReadingStatus.finished, finishedAt: null),
        [],
        [],
      );
      expect(s.progressLabel, '読了');
    });
  });

  group('BookDetailSummary 不正値ガード', () {
    test('負のreviewCountはArgumentError', () {
      expect(
        () => BookDetailSummary(
          reviewCount: -1,
          averageRating: null,
          favoriteNoteCount: 0,
          memoCount: 0,
          quoteCount: 0,
          lastActivityAt: null,
          progressLabel: '未読',
        ),
        throwsArgumentError,
      );
    });

    test('averageRatingが範囲外（6.0）はArgumentError', () {
      expect(
        () => BookDetailSummary(
          reviewCount: 1,
          averageRating: 6.0,
          favoriteNoteCount: 0,
          memoCount: 0,
          quoteCount: 0,
          lastActivityAt: null,
          progressLabel: '未読',
        ),
        throwsArgumentError,
      );
    });

    test('負のfavoriteNoteCountはArgumentError', () {
      expect(
        () => BookDetailSummary(
          reviewCount: 0,
          averageRating: null,
          favoriteNoteCount: -2,
          memoCount: 0,
          quoteCount: 0,
          lastActivityAt: null,
          progressLabel: '未読',
        ),
        throwsArgumentError,
      );
    });
  });
}
