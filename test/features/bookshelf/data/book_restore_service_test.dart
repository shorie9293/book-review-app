import 'dart:async';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/data/book_restore_service.dart';
import 'package:book_review_app/features/bookshelf/domain/book_restore.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book(String id) => Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: '書評 $id',
      createdAt: DateTime.utc(2026, 5, 1),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ $id',
      createdAt: DateTime.utc(2026, 5, 2),
    );

BookRestoreSnapshot _snapshot() => BookRestoreSnapshot(
      book: _book('book-1'),
      reviews: [_review('r1', 'book-1'), _review('r2', 'book-1')],
      notes: [_note('n1', 'book-1')],
    );

void main() {
  group('BookRestoreService（逆順連鎖復元）', () {
    test('復元は必ず book → notes → reviews の逆順で実行される', () async {
      final steps = <String>[];
      final service = BookRestoreService(
        addBook: (_) async {},
        addNote: (_) async {},
        addReview: (_) async {},
        onStep: steps.add,
      );

      final report = await service.restore(_snapshot());

      expect(steps, ['book', 'notes', 'reviews']);
      expect(report.bookRestored, isTrue);
      expect(report.restoredNotes, 1);
      expect(report.restoredReviews, 2);
      expect(report.hasFailures, isFalse);
    });

    test('途中ステップが失敗しても残りを続行し report に載る', () async {
      final steps = <String>[];
      final service = BookRestoreService(
        addBook: (_) async => throw StateError('本の復元に失敗'),
        addNote: (_) async {},
        addReview: (_) async {},
        onStep: steps.add,
      );

      final report = await service.restore(_snapshot());

      // 本が失敗しても notes / reviews は続行される
      expect(steps, ['book', 'notes', 'reviews']);
      expect(report.bookRestored, isFalse);
      expect(report.restoredNotes, 1);
      expect(report.restoredReviews, 2);
      expect(report.failures, ['book']);
    });

    test('1件のレビュー失敗でも残りのレビュー・メモは復元される', () async {
      final service = BookRestoreService(
        addBook: (_) async {},
        addNote: (_) async {},
        addReview: (review) async {
          if (review.id == 'r1') throw StateError('r1 失敗');
        },
      );

      final report = await service.restore(_snapshot());

      expect(report.restoredReviews, 1);
      expect(report.restoredNotes, 1);
      expect(report.failures, ['review:r1']);
    });

    test('注入されていないステップ（null）はスキップされる', () async {
      final steps = <String>[];
      final service = BookRestoreService(
        addBook: (_) async {},
        onStep: steps.add,
      );

      final report = await service.restore(_snapshot());

      expect(steps, ['book']);
      expect(report.bookRestored, isTrue);
      expect(report.restoredReviews, 0);
      expect(report.restoredNotes, 0);
      expect(report.hasFailures, isFalse);
    });

    test('全ステップが失敗しても例外を投げず report に集約する', () async {
      final service = BookRestoreService(
        addBook: (_) async => throw Exception('book'),
        addNote: (_) async => throw Exception('note'),
        addReview: (_) async => throw Exception('review'),
      );

      final report = await service.restore(_snapshot());

      expect(report.hasFailures, isTrue);
      expect(report.restoredTotal, 0);
      expect(report.failures, containsAll(['book', 'note:n1', 'review:r1']));
    });

    test('対象外の本のレビュー・ノートは復元しない', () async {
      final restoredReviewIds = <String>[];
      final restoredNoteIds = <String>[];
      final snapshot = BookRestoreSnapshot.capture(
        book: _book('book-1'),
        reviews: [_review('r1', 'book-1'), _review('rx', 'book-2')],
        notes: [_note('n1', 'book-1'), _note('nx', 'book-2')],
      );
      final service = BookRestoreService(
        addBook: (_) async {},
        addNote: (note) async => restoredNoteIds.add(note.id),
        addReview: (review) async => restoredReviewIds.add(review.id),
      );

      await service.restore(snapshot);

      expect(restoredReviewIds, ['r1']);
      expect(restoredNoteIds, ['n1']);
    });
  });

  group('BookRestoreService.restoreInIsolatedZone', () {
    test('復元中に zone へ飛んだ非同期例外は呼出元へ漏れない', () async {
      Object? leaked;
      final report = await runZonedGuarded(
        () => BookRestoreService(
          addBook: (_) async {
            // 待たない Future の例外は zone のハンドラへ飛ぶ
            unawaited(Future<void>.microtask(() => throw StateError('stray')));
          },
        ).restoreInIsolatedZone(_snapshot()),
        (error, stackTrace) {
          leaked = error;
        },
      );

      // 呼出元 zone を汚さない
      expect(leaked, isNull);
      expect(report, isA<BookRestoreReport>());
    });

    test('通常時は restore と同じ結果を返す', () async {
      final report = await BookRestoreService(
        addBook: (_) async {},
        addNote: (_) async {},
        addReview: (_) async {},
      ).restoreInIsolatedZone(_snapshot());

      expect(report.bookRestored, isTrue);
      expect(report.restoredNotes, 1);
      expect(report.restoredReviews, 2);
      expect(report.hasFailures, isFalse);
    });
  });
}
