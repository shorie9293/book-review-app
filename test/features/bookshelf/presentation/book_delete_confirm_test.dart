import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 本棚の削除導線だけを検証するためのインメモリ蔵書リポジトリ。
class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(List<Book> books) : _books = List.of(books);

  final List<Book> _books;

  /// removeBook に渡された ID の履歴
  final List<String> removedIds = [];

  @override
  Future<List<Book>> getBooks() async => List.of(_books);

  @override
  Future<Book?> getBookById(String id) async {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<Book?> findByIsbn(String isbn) async {
    for (final book in _books) {
      if (book.isbn == isbn) return book;
    }
    return null;
  }

  @override
  Future<void> addBook(Book book) async => _books.add(book);

  @override
  Future<void> updateBook(Book book) async {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) _books[index] = book;
  }

  @override
  Future<void> removeBook(String id) async {
    removedIds.add(id);
    _books.removeWhere((book) => book.id == id);
  }
}

/// 指定書籍のレビューを返し、削除された ID を記録するフェイク。
class _FakeReviewRepository implements ReviewRepository {
  _FakeReviewRepository({
    List<Review> reviews = const [],
    this.throwOnFetch = false,
  }) : _reviews = List.of(reviews);

  final List<Review> _reviews;
  final bool throwOnFetch;
  final List<String> deletedIds = [];

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async {
    if (throwOnFetch) throw StateError('レビュー取得失敗');
    return [
      for (final review in _reviews)
        if (review.bookId == bookId) review,
    ];
  }

  @override
  Future<void> addReview(Review review) async => _reviews.add(review);

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {
    deletedIds.add(id);
    _reviews.removeWhere((review) => review.id == id);
  }
}

/// 指定書籍のメモを返し、削除された ID を記録するフェイク。
class _FakeNoteRepository implements BookNoteRepository {
  _FakeNoteRepository({
    List<BookNote> notes = const [],
    this.throwOnFetch = false,
  }) : _notes = List.of(notes);

  final List<BookNote> _notes;
  final bool throwOnFetch;
  final List<String> deletedIds = [];

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async {
    if (throwOnFetch) throw StateError('メモ取得失敗');
    return [
      for (final note in _notes)
        if (note.bookId == bookId) note,
    ];
  }

  @override
  Future<List<BookNote>> getAllNotes() async => List.of(_notes);

  @override
  Future<void> addNote(BookNote note) async => _notes.add(note);

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<void> deleteNote(String id) async {
    deletedIds.add(id);
    _notes.removeWhere((note) => note.id == id);
  }

  @override
  Future<void> deleteNotesByBookId(String bookId) async {
    deletedIds.addAll([
      for (final note in _notes)
        if (note.bookId == bookId) note.id,
    ]);
    _notes.removeWhere((note) => note.bookId == bookId);
  }
}

Book _book(String id) => Book(
      id: id,
      title: '削除対象本',
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
  const bookId = 'book-1';

  Future<void> pumpShelf(
    WidgetTester tester, {
    required _FakeBookRepository books,
    ReviewRepository? reviews,
    BookNoteRepository? notes,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookshelfScreen(
          repository: books,
          initialBooks: await books.getBooks(),
          reviewRepository: reviews,
          noteRepository: notes,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('削除ボタンで確認ダイアログが出る', (tester) async {
    final books = _FakeBookRepository([_book(bookId)]);
    await pumpShelf(tester, books: books);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('書籍「削除対象本」を本棚から削除しますか？'), findsOneWidget);
    expect(find.byKey(const Key('book_delete_confirm')), findsOneWidget);
    expect(find.byKey(const Key('book_delete_cancel')), findsOneWidget);
    // 押すまでは削除しない
    expect(books.removedIds, isEmpty);
  });

  testWidgets('キャンセルでは removeBook を呼ばない', (tester) async {
    final books = _FakeBookRepository([_book(bookId)]);
    final reviews = _FakeReviewRepository(reviews: [_review('r1', bookId)]);
    await pumpShelf(tester, books: books, reviews: reviews);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_delete_cancel')));
    await tester.pumpAndSettle();

    expect(books.removedIds, isEmpty);
    expect(reviews.deletedIds, isEmpty);
    expect(find.text('削除対象本'), findsOneWidget);
  });

  testWidgets('確定で書籍・レビュー・メモがすべて削除される', (tester) async {
    final books = _FakeBookRepository([_book(bookId)]);
    final reviews = _FakeReviewRepository(
      reviews: [_review('r1', bookId), _review('r2', 'other')],
    );
    final notes = _FakeNoteRepository(notes: [_note('n1', bookId)]);
    await pumpShelf(
      tester,
      books: books,
      reviews: reviews,
      notes: notes,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_delete_confirm')));
    await tester.pumpAndSettle();

    expect(books.removedIds, [bookId]);
    expect(reviews.deletedIds, ['r1']);
    expect(notes.deletedIds, ['n1']);
    expect(find.text('削除対象本'), findsNothing);
  });

  testWidgets('添付ありのとき確認本文に書評N件・メモN件が入る', (tester) async {
    final books = _FakeBookRepository([_book(bookId)]);
    final reviews = _FakeReviewRepository(
      reviews: [_review('r1', bookId), _review('r2', bookId)],
    );
    final notes = _FakeNoteRepository(notes: [_note('n1', bookId)]);
    await pumpShelf(
      tester,
      books: books,
      reviews: reviews,
      notes: notes,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    final dialogText = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? '')
        .join('\n');
    expect(dialogText, contains('書評2件'));
    expect(dialogText, contains('メモ1件'));
  });

  testWidgets('レビュー・メモ取得が例外でもダイアログは出て削除できる', (tester) async {
    final books = _FakeBookRepository([_book(bookId)]);
    final reviews = _FakeReviewRepository(throwOnFetch: true);
    final notes = _FakeNoteRepository(throwOnFetch: true);
    await pumpShelf(
      tester,
      books: books,
      reviews: reviews,
      notes: notes,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('書籍「削除対象本」を本棚から削除しますか？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('book_delete_confirm')));
    await tester.pumpAndSettle();

    expect(books.removedIds, [bookId]);
    expect(find.text('削除対象本'), findsNothing);
  });

  testWidgets('リポジトリ未指定でも確認ダイアログが出て削除できる', (tester) async {
    final books = _FakeBookRepository([_book(bookId)]);
    await pumpShelf(tester, books: books);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_delete_confirm')));
    await tester.pumpAndSettle();

    expect(books.removedIds, [bookId]);
  });
}
