import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';

Book _book(String id, {List<String> genres = const []}) => Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: '978-4-0000-0000-$id',
      genres: genres,
      addedAt: DateTime.utc(2026, 1, 1),
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 3,
      text: 'text',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ',
      createdAt: DateTime.utc(2026, 3, 3),
    );

void main() {
  group('BackupService.build', () {
    test('exportedAt は注入された now の UTC 値', () {
      final fixed = DateTime(2026, 5, 1, 12, 0); // JST想定のローカル時刻
      final service = BackupService(now: () => fixed);
      final bundle = service.build(
        books: [_book('b1')],
        reviews: const [],
        notes: const [],
      );
      expect(bundle.exportedAt, fixed.toUtc());
      expect(bundle.books.single.id, 'b1');
    });
  });

  group('BackupService.exportJson / parse', () {
    test('exportJson はインデント整形JSONで、parse で往復できる', () {
      final service = BackupService(now: () => DateTime.utc(2026, 5, 1));
      final bundle = service.build(
        books: [_book('b1', genres: ['小説', 'SF'])],
        reviews: [_review('r1', 'b1')],
        notes: [_note('n1', 'b1')],
      );

      final json = service.exportJson(bundle);
      expect(json.contains('\n  '), isTrue, reason: 'インデント整形されていること');
      final decoded = jsonDecode(json);
      expect(decoded, isA<Map<String, dynamic>>());

      final restored = service.parse(json);
      expect(restored.books.single.id, 'b1');
      expect(restored.books.single.genres, ['小説', 'SF']);
      expect(restored.reviews.single.id, 'r1');
      expect(restored.notes.single.id, 'n1');
    });

    test('parse: 破損JSONは FormatException', () {
      const service = BackupService();
      expect(() => service.parse('{invalid'), throwsFormatException);
    });

    test('parse: 非オブジェクト（配列・文字列）は FormatException', () {
      const service = BackupService();
      expect(() => service.parse('[]'), throwsFormatException);
      expect(() => service.parse('"hello"'), throwsFormatException);
    });

    test('parse: 必須欠落は FormatException', () {
      const service = BackupService();
      expect(() => service.parse('{}'), throwsFormatException);
    });
  });

  group('BackupService.merge', () {
    test('既存に無いidだけ追加し、既存idはスキップ（既存優先）', () {
      const service = BackupService();
      final incoming = service.build(
        books: [_book('b1'), _book('b2')],
        reviews: [_review('r1', 'b1'), _review('r2', 'b2')],
        notes: [_note('n1', 'b1'), _note('n2', 'b2')],
      );

      final result = service.merge(
        incoming: incoming,
        existingBooks: [_book('b1', genres: ['既存'])],
        existingReviews: [_review('r2', 'other')],
        existingNotes: const [],
      );

      expect(result.booksAdded, 1);
      expect(result.booksSkipped, 1);
      expect(result.reviewsAdded, 1);
      expect(result.reviewsSkipped, 1);
      expect(result.notesAdded, 2);
      expect(result.notesSkipped, 0);
      expect(result.totalAdded, 4);
      expect(result.totalSkipped, 2);
      expect(result.isEmpty, isFalse);
    });

    test('incoming 内の重複idは1件に畳まれる', () {
      const service = BackupService();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026, 5, 1),
        books: [_book('b1'), _book('b1'), _book('b2')],
        reviews: [_review('r1', 'b1'), _review('r1', 'b1')],
        notes: const [],
      );

      final result = service.merge(
        incoming: bundle,
        existingBooks: const [],
        existingReviews: const [],
        existingNotes: const [],
      );

      expect(result.booksAdded, 2);
      expect(result.booksSkipped, 1);
      expect(result.reviewsAdded, 1);
      expect(result.reviewsSkipped, 1);
    });

    test('全部スキップなら isEmpty', () {
      const service = BackupService();
      final incoming = service.build(
        books: [_book('b1')],
        reviews: const [],
        notes: const [],
      );
      final result = service.merge(
        incoming: incoming,
        existingBooks: [_book('b1')],
        existingReviews: const [],
        existingNotes: const [],
      );
      expect(result.isEmpty, isTrue);
      expect(result.totalAdded, 0);
    });
  });

  group('BackupService.exportBooksCsv', () {
    test('ヘッダ行と基本フィールド', () {
      final csv = BackupService.exportBooksCsv([
        Book(
          id: 'b1',
          title: '吾輩は猫である',
          author: '夏目漱石',
          isbn: '978-4-10-101001-1',
          genres: const ['小説', '古典'],
          readingStatus: ReadingStatus.finished,
          currentPage: 300,
          pageCount: 300,
          addedAt: DateTime.utc(2026, 1, 1),
          finishedAt: DateTime.utc(2026, 2, 1),
        ),
      ]);
      final lines = csv.split('\n');
      expect(lines.first,
          'id,title,author,isbn,genres,readingStatus,currentPage,pageCount,addedAt,finishedAt');
      expect(lines[1],
          'b1,吾輩は猫である,夏目漱石,978-4-10-101001-1,小説;古典,finished,300,300,2026-01-01T00:00:00.000Z,2026-02-01T00:00:00.000Z');
      expect(csv.endsWith('\n'), isTrue);
      expect(lines.last, isEmpty);
    });

    test('カン・引用符・改行を含む値は RFC4180 エスケープされる', () {
      final csv = BackupService.exportBooksCsv([
        Book(
          id: 'b1',
          title: 'タイトル, カンマと"引用符"',
          author: 'multi\nline',
          isbn: '',
          genres: const ['a,b', 'c"d'],
        ),
      ]);
      final row =
          'b1,"タイトル, カンマと""引用符""","multi\nline",,"a,b;c""d",unread,0,,,';
      expect(csv.contains(row), isTrue);
    });

    test('空リストはヘッダ行のみ', () {
      final csv = BackupService.exportBooksCsv(const []);
      expect(csv,
          'id,title,author,isbn,genres,readingStatus,currentPage,pageCount,addedAt,finishedAt\n');
    });
  });
}
