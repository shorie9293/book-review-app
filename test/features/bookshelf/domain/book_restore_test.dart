import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
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

void main() {
  group('BookRestorePlan（復元順の宣言固定）', () {
    test('復元順は削除順 reviews → notes → book の逆順に固定されている', () {
      expect(
        BookRestorePlan.steps,
        const [
          BookRestoreStep.book,
          BookRestoreStep.notes,
          BookRestoreStep.reviews,
        ],
      );
      expect(BookRestorePlan.stepNames, ['book', 'notes', 'reviews']);
    });

    test('削除順を反転すると復元順に一致する', () {
      expect(
        BookRestorePlan.reverseOfDeletionOrder(
            const ['reviews', 'notes', 'book']),
        BookRestorePlan.stepNames,
      );
    });

    test('宣言された順序リストは変更できない', () {
      expect(
        () => BookRestorePlan.steps.add(BookRestoreStep.book),
        throwsUnsupportedError,
      );
    });
  });

  group('BookRestoreSnapshot', () {
    test('book / reviews / notes をそのまま保持する', () {
      final snapshot = BookRestoreSnapshot(
        book: _book('book-1'),
        reviews: [_review('r1', 'book-1')],
        notes: [_note('n1', 'book-1')],
      );

      expect(snapshot.bookId, 'book-1');
      expect(snapshot.reviews.single.id, 'r1');
      expect(snapshot.notes.single.id, 'n1');
      expect(snapshot.attachmentCount, 2);
      expect(snapshot.hasAttachments, isTrue);
    });

    test('空の書籍IDは ArgumentError', () {
      expect(
        () => BookRestoreSnapshot(book: _book('')),
        throwsArgumentError,
      );
    });

    test('空のレビューIDは ArgumentError（メモはモデル側が空IDを拒否）', () {
      expect(
        () => BookRestoreSnapshot(
          book: _book('book_1'),
          reviews: [_review('', 'book_1')],
        ),
        throwsArgumentError,
      );
      // BookNote / Book はモデル自身が空IDを assert で拒否するため、
      // スナップショットまで空IDが届かない（二重防御）。
      expect(() => _note('', 'book_1'), throwsA(isA<AssertionError>()));
    });

    test('capture は対象書籍の添付だけを取り込み、他書は巻き込まない', () {
      final snapshot = BookRestoreSnapshot.capture(
        book: _book('book-1'),
        reviews: [
          _review('r1', 'book-1'),
          _review('r2', 'book-2'),
          _review('r3', 'book-1'),
        ],
        notes: [
          _note('n1', 'book-2'),
          _note('n2', 'book-1'),
        ],
      );

      expect([for (final r in snapshot.reviews) r.id], ['r1', 'r3']);
      expect([for (final n in snapshot.notes) n.id], ['n2']);
    });
  });
}
