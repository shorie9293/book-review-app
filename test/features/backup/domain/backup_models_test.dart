import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';

import 'package:book_review_app/domain/models/reading_status.dart';

Book _book(String id, {ReadingStatus readingStatus = ReadingStatus.reading}) =>
    Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: '978-4-0000-0000-$id',
      genres: const ['小説'],
      readingStatus: readingStatus,
      currentPage: 12,
      pageCount: 300,
      addedAt: DateTime.utc(2026, 1, 1),
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: '良い本',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ内容',
      createdAt: DateTime.utc(2026, 3, 3),
    );

void main() {
  group('BackupBundle', () {
    test('スキーマバージョンは kBackupSchemaVersion と一致', () {
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026, 4, 1),
        books: const [],
        reviews: const [],
        notes: const [],
      );
      expect(bundle.schemaVersion, kBackupSchemaVersion);
      expect(bundle.isEmpty, isTrue);
    });

    test('schemaVersion<1 は ArgumentError', () {
      expect(
        () => BackupBundle(
          schemaVersion: 0,
          exportedAt: DateTime.utc(2026, 4, 1),
          books: const [],
          reviews: const [],
          notes: const [],
        ),
        throwsArgumentError,
      );
    });

    test('isEmpty は4リスト…ではなく3リスト合計0で判定', () {
      final book = _book('b1');
      final empty = BackupBundle(
        exportedAt: DateTime.utc(2026, 4, 1),
        books: const [],
        reviews: const [],
        notes: const [],
      );
      final nonEmpty = BackupBundle(
        exportedAt: DateTime.utc(2026, 4, 1),
        books: [book],
        reviews: const [],
        notes: const [],
      );
      expect(empty.isEmpty, isTrue);
      expect(nonEmpty.isEmpty, isFalse);
    });

    test('toJson/fromJson の往復で内容が保存される', () {
      final book = _book('b1');
      final review = _review('r1', 'b1');
      final note = _note('n1', 'b1');
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026, 4, 1, 12, 30),
        books: [book],
        reviews: [review],
        notes: [note],
      );

      final restored = BackupBundle.fromJson(bundle.toJson());

      expect(restored.schemaVersion, bundle.schemaVersion);
      expect(restored.exportedAt, bundle.exportedAt);
      expect(restored.books.single.id, 'b1');
      expect(restored.books.single.title, book.title);
      expect(restored.books.single.genres, ['小説']);
      expect(restored.books.single.readingStatus.name, 'reading');
      expect(restored.books.single.currentPage, 12);
      expect(restored.books.single.addedAt, book.addedAt);
      expect(restored.reviews.single.id, 'r1');
      expect(restored.reviews.single.rating, 4);
      expect(restored.notes.single.id, 'n1');
      expect(restored.notes.single.content, 'メモ内容');
      expect(restored.isEmpty, isFalse);
    });

    test('fromJson: 必須欠落は FormatException', () {
      expect(() => BackupBundle.fromJson({}), throwsFormatException);
      expect(
        () => BackupBundle.fromJson({
          'exportedAt': DateTime.utc(2026, 4, 1).toIso8601String(),
          'books': <Object>[],
          'reviews': <Object>[],
          'notes': <Object>[],
        }),
        throwsFormatException,
      );
    });

    test('fromJson: 不正な exportedAt は FormatException', () {
      expect(
        () => BackupBundle.fromJson(const {
          'schemaVersion': 1,
          'exportedAt': 'not-a-date',
          'books': <Object>[],
          'reviews': <Object>[],
          'notes': <Object>[],
        }),
        throwsFormatException,
      );
    });

    test('fromJson: 型不一致は FormatException', () {
      expect(
        () => BackupBundle.fromJson(const {
          'schemaVersion': 1,
          'exportedAt': '2026-04-01T00:00:00Z',
          'books': ['not-a-map'],
          'reviews': <Object>[],
          'notes': <Object>[],
        }),
        throwsFormatException,
      );
    });

    test('fromJson: 破損Bookは FormatException', () {
      expect(
        () => BackupBundle.fromJson(const {
          'schemaVersion': 1,
          'exportedAt': '2026-04-01T00:00:00Z',
          'books': [
            {'title': 'id欠け'}
          ],
          'reviews': <Object>[],
          'notes': <Object>[],
        }),
        throwsFormatException,
      );
    });

    test('BackupSummary.of / label', () {
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026, 4, 1),
        books: [_book('b1'), _book('b2'), _book('b3')],
        reviews: [_review('r1', 'b1')],
        notes: [_note('n1', 'b1'), _note('n2', 'b1')],
      );
      final summary = BackupSummary.of(bundle);
      expect(summary.books, 3);
      expect(summary.reviews, 1);
      expect(summary.notes, 2);
      expect(summary.total, 6);
      expect(summary.label, '蔵書 3冊 / レビュー 1件 / メモ 2件');
    });

    test('BackupMergeResult getters', () {
      const result = BackupMergeResult(
        booksAdded: 2,
        reviewsAdded: 1,
        notesAdded: 3,
        booksSkipped: 1,
        reviewsSkipped: 0,
        notesSkipped: 2,
      );
      expect(result.totalAdded, 6);
      expect(result.totalSkipped, 3);
      expect(result.isEmpty, isFalse);
      expect(
        const BackupMergeResult(
          booksAdded: 0,
          reviewsAdded: 0,
          notesAdded: 0,
          booksSkipped: 1,
          reviewsSkipped: 0,
          notesSkipped: 0,
        ).isEmpty,
        isTrue,
      );
    });
  });
}
