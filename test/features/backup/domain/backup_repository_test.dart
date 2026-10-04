import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';

Book _book(String id) => Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
      addedAt: DateTime.utc(2026, 1, 1),
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 5,
      text: 'text',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ $id',
      createdAt: DateTime.utc(2026, 3, 3),
    );

/// テスト用の簡易 BookRepository
class _FakeBookRepository implements BookRepository {
  final Map<String, Book> store;
  _FakeBookRepository(List<Book> initial)
      : store = {for (final b in initial) b.id: b};

  @override
  Future<List<Book>> getBooks() async => store.values.toList();

  @override
  Future<Book?> getBookById(String id) async => store[id];

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async => store[book.id] = book;

  @override
  Future<void> updateBook(Book book) async => store[book.id] = book;

  @override
  Future<void> removeBook(String id) async => store.remove(id);
}

/// テスト用の簡易 ReviewRepository
class _FakeReviewRepository implements ReviewRepository {
  final Map<String, Review> store;
  _FakeReviewRepository(List<Review> initial)
      : store = {for (final r in initial) r.id: r};

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async =>
      store.values.where((r) => r.bookId == bookId).toList();

  @override
  Future<void> addReview(Review review) async => store[review.id] = review;

  @override
  Future<void> updateReview(Review review) async => store[review.id] = review;

  @override
  Future<void> deleteReview(String id) async => store.remove(id);
}

/// テスト用の簡易 BookNoteRepository
class _FakeNoteRepository implements BookNoteRepository {
  final Map<String, BookNote> store;
  _FakeNoteRepository(List<BookNote> initial)
      : store = {for (final n in initial) n.id: n};

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async =>
      store.values.where((n) => n.bookId == bookId).toList();

  @override
  Future<List<BookNote>> getAllNotes() async => store.values.toList();

  @override
  Future<void> addNote(BookNote note) async => store[note.id] = note;

  @override
  Future<void> updateNote(BookNote note) async => store[note.id] = note;

  @override
  Future<void> deleteNote(String id) async => store.remove(id);

  @override
  Future<void> deleteNotesByBookId(String bookId) async =>
      store.removeWhere((_, n) => n.bookId == bookId);
}

void main() {
  group('InMemoryBackupRepository', () {
    test('collect は注入リストの内容を返す', () async {
      final books = [_book('b1')];
      final reviews = [_review('r1', 'b1')];
      final notes = [_note('n1', 'b1')];
      final repo = InMemoryBackupRepository(
        books: books,
        reviews: reviews,
        notes: notes,
      );

      final bundle = await repo.collect();
      expect(bundle.schemaVersion, kBackupSchemaVersion);
      expect(bundle.books.single.id, 'b1');
      expect(bundle.reviews.single.id, 'r1');
      expect(bundle.notes.single.id, 'n1');
    });

    test('restore は追加分のみリストへ足し込む（既存優先）', () async {
      final books = [_book('b1')];
      final reviews = <Review>[];
      final notes = <BookNote>[];
      final repo = InMemoryBackupRepository(
        books: books,
        reviews: reviews,
        notes: notes,
      );

      const service = BackupService();
      final incoming = service.build(
        books: [_book('b1'), _book('b2')],
        reviews: [_review('r1', 'b2')],
        notes: [_note('n1', 'b2')],
      );

      final result = await repo.restore(incoming);
      expect(result.booksAdded, 1);
      expect(result.booksSkipped, 1);
      expect(result.reviewsAdded, 1);
      expect(result.notesAdded, 1);
      expect(books.map((b) => b.id), ['b1', 'b2']);
      expect(reviews.single.id, 'r1');
      expect(notes.single.id, 'n1');
    });

    test('restore 後の再 restore は全件スキップされる', () async {
      final books = <Book>[];
      final repo = InMemoryBackupRepository(
        books: books,
        reviews: [],
        notes: [],
      );
      const service = BackupService();
      final incoming = service.build(
        books: [_book('b1')],
        reviews: const [],
        notes: const [],
      );

      await repo.restore(incoming);
      final second = await repo.restore(incoming);
      expect(second.isEmpty, isTrue);
      expect(books.length, 1);
    });
  });

  group('HiveBackupRepository（Fakeリポジトリ注入）', () {
    test('collect は books × reviews(本ごと) + notes を束ねる', () async {
      final bookRepo = _FakeBookRepository([_book('b1'), _book('b2')]);
      final reviewRepo = _FakeReviewRepository([
        _review('r1', 'b1'),
        _review('r2', 'b1'),
        _review('r3', 'b2'),
      ]);
      final noteRepo = _FakeNoteRepository([_note('n1', 'b1')]);
      final repo = HiveBackupRepository(
        bookRepository: bookRepo,
        reviewRepository: reviewRepo,
        noteRepository: noteRepo,
      );

      final bundle = await repo.collect();
      expect(bundle.books.length, 2);
      expect(bundle.reviews.length, 3);
      expect(bundle.notes.length, 1);
      // 本の順にレビューが連結される
      expect(bundle.reviews.map((r) => r.id).toSet(), {'r1', 'r2', 'r3'});
    });

    test('restore は追加のみ add* を呼び、既存は上書きしない', () async {
      final bookRepo = _FakeBookRepository([_book('b1')]);
      final reviewRepo = _FakeReviewRepository(const []);
      final noteRepo = _FakeNoteRepository(const []);
      final repo = HiveBackupRepository(
        bookRepository: bookRepo,
        reviewRepository: reviewRepo,
        noteRepository: noteRepo,
      );

      const service = BackupService();
      final incoming = service.build(
        books: [_book('b1'), _book('b2')],
        reviews: [_review('r1', 'b2')],
        notes: [_note('n1', 'b2')],
      );

      final result = await repo.restore(incoming);

      expect(result.booksAdded, 1);
      expect(result.booksSkipped, 1);
      expect(result.reviewsAdded, 1);
      expect(result.notesAdded, 1);
      // 既存 b1 の内容は上書きされない（title は元のまま）
      expect(bookRepo.store['b1']!.title, '本 b1');
      expect(bookRepo.store.containsKey('b2'), isTrue);
      expect(reviewRepo.store['r1'], isNotNull);
      expect(noteRepo.store['n1'], isNotNull);
    });
  });
}
