import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/data/book_deletion_service.dart';
import 'package:book_review_app/features/bookshelf/domain/book_deletion.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 9, 12);

Review _review({required String id, required String bookId}) {
  return Review(
    id: id,
    bookId: bookId,
    rating: 3,
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
  group('BookDeletionService.deleteBookWithAttachments', () {
    test('削除順序は reviews → notes → book に固定される', () async {
      final calls = <String>[];
      final steps = <String>[];
      final service = BookDeletionService(
        deleteReviews: (ids) async => calls.add('reviews:${ids.join(",")}'),
        deleteNotesByBookId: (bookId) async => calls.add('notes:$bookId'),
        deleteBook: (bookId) async => calls.add('book:$bookId'),
        onStep: steps.add,
      );

      final report = await service.deleteBookWithAttachments(
        bookId: 'b1',
        plan: BookDeletionPlan(reviewCount: 2, noteCount: 3),
        reviewIds: ['r1', 'r2'],
      );

      expect(calls, ['reviews:r1,r2', 'notes:b1', 'book:b1']);
      expect(steps, ['reviews', 'notes', 'book']);
      expect(report.deletedReviews, 2);
      expect(report.deletedNotes, 3);
      expect(report.bookDeleted, isTrue);
      expect(report.hasFailures, isFalse);
    });

    test('レビュー削除が失敗してもメモ・本の削除を継続する', () async {
      final calls = <String>[];
      final service = BookDeletionService(
        deleteReviews: (_) async {
          calls.add('reviews');
          throw Exception('boom');
        },
        deleteNotesByBookId: (bookId) async => calls.add('notes:$bookId'),
        deleteBook: (bookId) async => calls.add('book:$bookId'),
      );

      final report = await service.deleteBookWithAttachments(
        bookId: 'b1',
        plan: BookDeletionPlan(reviewCount: 1, noteCount: 2),
        reviewIds: ['r1'],
      );

      expect(calls, ['reviews', 'notes:b1', 'book:b1']);
      expect(report.failures, ['reviews']);
      expect(report.hasFailures, isTrue);
      expect(report.deletedReviews, 0);
      expect(report.deletedNotes, 2);
      expect(report.bookDeleted, isTrue);
    });

    test('メモ削除が失敗しても本の削除を継続する', () async {
      final calls = <String>[];
      final service = BookDeletionService(
        deleteReviews: (_) async => calls.add('reviews'),
        deleteNotesByBookId: (_) async {
          calls.add('notes');
          throw Exception('boom');
        },
        deleteBook: (bookId) async => calls.add('book:$bookId'),
      );

      final report = await service.deleteBookWithAttachments(
        bookId: 'b1',
        plan: BookDeletionPlan(reviewCount: 1, noteCount: 1),
        reviewIds: ['r1'],
      );

      expect(calls, ['reviews', 'notes', 'book:b1']);
      expect(report.failures, ['notes']);
      expect(report.deletedReviews, 1);
      expect(report.deletedNotes, 0);
      expect(report.bookDeleted, isTrue);
    });

    test('本の削除が失敗したら bookDeleted=false で failures に book', () async {
      final service = BookDeletionService(
        deleteReviews: (_) async {},
        deleteNotesByBookId: (_) async {},
        deleteBook: (_) async => throw Exception('boom'),
      );

      final report = await service.deleteBookWithAttachments(
        bookId: 'b1',
        plan: BookDeletionPlan(reviewCount: 1, noteCount: 1),
        reviewIds: ['r1'],
      );

      expect(report.failures, ['book']);
      expect(report.bookDeleted, isFalse);
      expect(report.deletedReviews, 1);
      expect(report.deletedNotes, 1);
    });

    test('全ステップ失敗でも例外を投げず failures に3件積む', () async {
      final service = BookDeletionService(
        deleteReviews: (_) async => throw Exception('r'),
        deleteNotesByBookId: (_) async => throw Exception('n'),
        deleteBook: (_) async => throw Exception('b'),
      );

      final future = service.deleteBookWithAttachments(
        bookId: 'b1',
        plan: BookDeletionPlan(reviewCount: 1, noteCount: 1),
        reviewIds: ['r1'],
      );
      await expectLater(future, completes);
      final report = await future;

      expect(report.failures, ['reviews', 'notes', 'book']);
      expect(report.deletedReviews, 0);
      expect(report.deletedNotes, 0);
      expect(report.bookDeleted, isFalse);
    });

    test('コールバックが null のステップはスキップされ失敗扱いにならない', () async {
      final calls = <String>[];
      final service = BookDeletionService(
        deleteBook: (bookId) async => calls.add('book:$bookId'),
      );

      final report = await service.deleteBookWithAttachments(
        bookId: 'b1',
        plan: BookDeletionPlan(reviewCount: 4, noteCount: 5),
      );

      expect(calls, ['book:b1']);
      expect(report.hasFailures, isFalse);
      expect(report.deletedReviews, 0);
      expect(report.deletedNotes, 0);
      expect(report.bookDeleted, isTrue);
    });

    test('添付0件ならレビュー・メモのコールバックを呼ばない', () async {
      final calls = <String>[];
      final service = BookDeletionService(
        deleteReviews: (_) async => calls.add('reviews'),
        deleteNotesByBookId: (_) async => calls.add('notes'),
        deleteBook: (_) async => calls.add('book'),
      );

      await service.deleteBookWithAttachments(
        bookId: 'b1',
        plan: BookDeletionPlan(reviewCount: 0, noteCount: 0),
      );

      expect(calls, ['book']);
    });
  });

  group('BookDeletionService.deleteOrphans', () {
    test('孤児レビュー・メモを1件ずつ削除し件数を返す', () async {
      final deleted = <String>[];
      final service = BookDeletionService(
        deleteReviewById: (id) async => deleted.add('review:$id'),
        deleteNoteById: (id) async => deleted.add('note:$id'),
      );
      final data = OrphanData(
        orphanReviews: [
          _review(id: 'r1', bookId: 'gone1'),
          _review(id: 'r2', bookId: 'gone2'),
        ],
        orphanNotes: [_note(id: 'n1', bookId: 'gone1')],
      );

      final report = await service.deleteOrphans(data);

      expect(deleted, ['review:r1', 'review:r2', 'note:n1']);
      expect(report.deletedReviews, 2);
      expect(report.deletedNotes, 1);
      expect(report.bookDeleted, isFalse);
      expect(report.hasFailures, isFalse);
    });

    test('一部が失敗しても残りを削除し failures に記録する', () async {
      final deleted = <String>[];
      final service = BookDeletionService(
        deleteReviewById: (id) async {
          if (id == 'r2') throw Exception('boom');
          deleted.add('review:$id');
        },
        deleteNoteById: (id) async {
          if (id == 'n1') throw Exception('boom');
          deleted.add('note:$id');
        },
      );
      final data = OrphanData(
        orphanReviews: [
          _review(id: 'r1', bookId: 'gone'),
          _review(id: 'r2', bookId: 'gone'),
          _review(id: 'r3', bookId: 'gone'),
        ],
        orphanNotes: [
          _note(id: 'n1', bookId: 'gone'),
          _note(id: 'n2', bookId: 'gone'),
        ],
      );

      final future = service.deleteOrphans(data);
      await expectLater(future, completes);
      final report = await future;

      expect(deleted, ['review:r1', 'review:r3', 'note:n2']);
      expect(report.deletedReviews, 2);
      expect(report.deletedNotes, 1);
      expect(report.failures, ['review:r2', 'note:n1']);
      expect(report.hasFailures, isTrue);
    });

    test('空の OrphanData は no-op', () async {
      final calls = <String>[];
      final service = BookDeletionService(
        deleteReviewById: (id) async => calls.add('review:$id'),
        deleteNoteById: (id) async => calls.add('note:$id'),
      );

      final report = await service.deleteOrphans(OrphanData.detect(
        books: const [],
        reviews: const [],
        notes: const [],
      ));

      expect(calls, isEmpty);
      expect(report.deletedReviews, 0);
      expect(report.deletedNotes, 0);
      expect(report.failures, isEmpty);
    });
  });
}
