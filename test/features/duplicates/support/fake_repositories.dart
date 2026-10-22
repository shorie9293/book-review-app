import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';

/// 試練用のインメモリ蔵書リポジトリ。
class FakeBookRepository implements BookRepository {
  FakeBookRepository([List<Book> initialBooks = const []])
      : books = List<Book>.of(initialBooks);

  /// 現在の蔵書（試練から直接検証できる）。
  final List<Book> books;

  /// getBooks が呼ばれた回数。
  int getBooksCalls = 0;

  /// addBook が呼ばれた回数。
  int addBookCalls = 0;

  /// true にすると updateBook が例外を投げる。
  bool failOnUpdate = false;

  /// true にすると removeBook が例外を投げる。
  bool failOnRemove = false;

  /// 現在の蔵書 id 一覧。
  List<String> get bookIds => books.map((b) => b.id).toList();

  @override
  Future<List<Book>> getBooks() async {
    getBooksCalls++;
    return List<Book>.of(books);
  }

  @override
  Future<Book?> getBookById(String id) async {
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<Book?> findByIsbn(String isbn) async {
    for (final book in books) {
      if (book.isbn == isbn) return book;
    }
    return null;
  }

  @override
  Future<void> addBook(Book book) async {
    addBookCalls++;
    books.add(book);
  }

  @override
  Future<void> updateBook(Book book) async {
    if (failOnUpdate) throw Exception('update failed');
    final index = books.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      books[index] = book;
    } else {
      books.add(book);
    }
  }

  @override
  Future<void> removeBook(String id) async {
    if (failOnRemove) throw Exception('remove failed');
    books.removeWhere((b) => b.id == id);
  }
}

/// 試練用のインメモリ・メモリポジトリ。
class FakeNoteRepository implements BookNoteRepository {
  FakeNoteRepository([List<BookNote> initialNotes = const []])
      : notes = List<BookNote>.of(initialNotes);

  /// 現在のメモ（試練から直接検証できる）。
  final List<BookNote> notes;

  /// updateNote が呼ばれた回数。
  int updateCalls = 0;

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async =>
      notes.where((n) => n.bookId == bookId).toList();

  @override
  Future<List<BookNote>> getAllNotes() async => List<BookNote>.of(notes);

  @override
  Future<void> addNote(BookNote note) async => notes.add(note);

  @override
  Future<void> updateNote(BookNote note) async {
    updateCalls++;
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.add(note);
    }
  }

  @override
  Future<void> deleteNote(String id) async =>
      notes.removeWhere((n) => n.id == id);

  @override
  Future<void> deleteNotesByBookId(String bookId) async =>
      notes.removeWhere((n) => n.bookId == bookId);
}

/// 試練用のインメモリレビューリポジトリ。
class FakeReviewRepository implements ReviewRepository {
  FakeReviewRepository([List<Review> initialReviews = const []])
      : reviews = List<Review>.of(initialReviews);

  /// 現在のレビュー（試練から直接検証できる）。
  final List<Review> reviews;

  /// updateReview が呼ばれた回数。
  int updateCalls = 0;

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async =>
      reviews.where((r) => r.bookId == bookId).toList();

  @override
  Future<void> addReview(Review review) async => reviews.add(review);

  @override
  Future<void> updateReview(Review review) async {
    updateCalls++;
    final index = reviews.indexWhere((r) => r.id == review.id);
    if (index >= 0) {
      reviews[index] = review;
    } else {
      reviews.add(review);
    }
  }

  @override
  Future<void> deleteReview(String id) async =>
      reviews.removeWhere((r) => r.id == id);
}
