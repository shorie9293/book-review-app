import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/domain/book_deletion.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 9, 12);

Book _book({required String id}) {
  return Book(id: id, title: '本$id', author: '著者$id', isbn: 'isbn-$id');
}

Review _review({required String id, required String bookId}) {
  return Review(
    id: id,
    bookId: bookId,
    rating: 4,
    text: '書評$id',
    createdAt: _now,
  );
}

BookNote _note({required String id, required String bookId}) {
  return BookNote(
    id: id,
    bookId: bookId,
    content: 'メモ$id',
    createdAt: _now,
  );
}

void main() {
  group('BookDeletionPlan.build', () {
    test('bookId に一致するレビュー・メモの件数を数える', () {
      final plan = BookDeletionPlan.build(
        bookId: 'b1',
        reviews: [
          _review(id: 'r1', bookId: 'b1'),
          _review(id: 'r2', bookId: 'b2'),
          _review(id: 'r3', bookId: 'b1'),
        ],
        notes: [
          _note(id: 'n1', bookId: 'b1'),
          _note(id: 'n2', bookId: 'b2'),
        ],
      );

      expect(plan.reviewCount, 2);
      expect(plan.noteCount, 1);
    });

    test('一致が無ければ 0 件', () {
      final plan = BookDeletionPlan.build(
        bookId: 'b9',
        reviews: [_review(id: 'r1', bookId: 'b1')],
        notes: [_note(id: 'n1', bookId: 'b1')],
      );

      expect(plan.reviewCount, 0);
      expect(plan.noteCount, 0);
    });

    test('空リストなら 0 件', () {
      final plan = BookDeletionPlan.build(
        bookId: 'b1',
        reviews: const [],
        notes: const [],
      );

      expect(plan.attachmentCount, 0);
      expect(plan.hasAttachments, isFalse);
    });
  });

  group('BookDeletionPlan', () {
    test('attachmentCount はレビュー＋メモの合計', () {
      const plan = BookDeletionPlan.none;
      expect(plan.attachmentCount, 0);

      final built = BookDeletionPlan(reviewCount: 3, noteCount: 5);
      expect(built.attachmentCount, 8);
      expect(built.hasAttachments, isTrue);
    });

    test('添付なしなら warningSuffix は null', () {
      final plan = BookDeletionPlan(reviewCount: 0, noteCount: 0);
      expect(plan.warningSuffix, isNull);
    });

    test('書評とメモの両方がある場合は両方を含む', () {
      final plan = BookDeletionPlan(reviewCount: 3, noteCount: 5);
      expect(plan.warningSuffix, 'この本の書評3件・メモ5件も一緒に消えます。');
    });

    test('書評0件なら書評の句を省略する', () {
      final plan = BookDeletionPlan(reviewCount: 0, noteCount: 5);
      expect(plan.warningSuffix, 'この本のメモ5件も一緒に消えます。');
    });

    test('メモ0件ならメモの句を省略する', () {
      final plan = BookDeletionPlan(reviewCount: 3, noteCount: 0);
      expect(plan.warningSuffix, 'この本の書評3件も一緒に消えます。');
    });

    test('負のレビュー件数は ArgumentError', () {
      expect(
        () => BookDeletionPlan(reviewCount: -1, noteCount: 0),
        throwsArgumentError,
      );
    });

    test('負のメモ件数は ArgumentError', () {
      expect(
        () => BookDeletionPlan(reviewCount: 0, noteCount: -2),
        throwsArgumentError,
      );
    });

    test('const none は 0 件計画と等価', () {
      expect(BookDeletionPlan.none,
          BookDeletionPlan(reviewCount: 0, noteCount: 0));
    });
  });

  group('OrphanData.detect', () {
    test('蔵書に無い bookId のレビュー・メモだけを抽出する', () {
      final data = OrphanData.detect(
        books: [_book(id: 'b1')],
        reviews: [
          _review(id: 'r1', bookId: 'b1'),
          _review(id: 'r2', bookId: 'gone'),
        ],
        notes: [
          _note(id: 'n1', bookId: 'gone'),
          _note(id: 'n2', bookId: 'b1'),
        ],
      );

      expect(data.orphanReviews.map((r) => r.id), ['r2']);
      expect(data.orphanNotes.map((n) => n.id), ['n1']);
    });

    test('入力順を保持する', () {
      final data = OrphanData.detect(
        books: const [],
        reviews: [
          _review(id: 'r3', bookId: 'x'),
          _review(id: 'r1', bookId: 'y'),
          _review(id: 'r2', bookId: 'z'),
        ],
        notes: [
          _note(id: 'n2', bookId: 'x'),
          _note(id: 'n1', bookId: 'y'),
        ],
      );

      expect(data.orphanReviews.map((r) => r.id), ['r3', 'r1', 'r2']);
      expect(data.orphanNotes.map((n) => n.id), ['n2', 'n1']);
    });

    test('入力リストを破壊しない', () {
      final reviews = [
        _review(id: 'r1', bookId: 'gone'),
        _review(id: 'r2', bookId: 'b1'),
      ];
      final notes = [_note(id: 'n1', bookId: 'gone')];

      OrphanData.detect(
        books: [_book(id: 'b1')],
        reviews: reviews,
        notes: notes,
      );

      expect(reviews.length, 2);
      expect(reviews.map((r) => r.id), ['r1', 'r2']);
      expect(notes.length, 1);
    });

    test('蔵書が空なら全件が孤児になる', () {
      final data = OrphanData.detect(
        books: const [],
        reviews: [_review(id: 'r1', bookId: 'b1')],
        notes: [_note(id: 'n1', bookId: 'b1')],
      );

      expect(data.total, 2);
      expect(data.isEmpty, isFalse);
    });

    test('孤児が無ければ isEmpty が true', () {
      final data = OrphanData.detect(
        books: [_book(id: 'b1')],
        reviews: [_review(id: 'r1', bookId: 'b1')],
        notes: [_note(id: 'n1', bookId: 'b1')],
      );

      expect(data.isEmpty, isTrue);
      expect(data.total, 0);
    });
  });

  group('OrphanData', () {
    test('total はレビュー＋メモの合計', () {
      final data = OrphanData(
        orphanReviews: [
          _review(id: 'r1', bookId: 'x'),
          _review(id: 'r2', bookId: 'y'),
          _review(id: 'r3', bookId: 'z'),
        ],
        orphanNotes: [
          _note(id: 'n1', bookId: 'x'),
          _note(id: 'n2', bookId: 'y')
        ],
      );

      expect(data.total, 5);
    });

    test('summaryLabel は0件の側も明記する', () {
      final data = OrphanData(
        orphanReviews: [
          _review(id: 'r1', bookId: 'x'),
          _review(id: 'r2', bookId: 'y'),
          _review(id: 'r3', bookId: 'z'),
        ],
        orphanNotes: [
          _note(id: 'n1', bookId: 'x'),
          _note(id: 'n2', bookId: 'y')
        ],
      );

      expect(data.summaryLabel, '本の無い書評 3件／メモ 2件');
    });

    test('空の OrphanData は 0件ラベルを返す', () {
      const data = OrphanData();

      expect(data.isEmpty, isTrue);
      expect(data.total, 0);
      expect(data.summaryLabel, '本の無い書評 0件／メモ 0件');
    });
  });
}
