import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/undo/presentation/undo_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 本棚の削除→Undo を検証するためのインメモリ蔵書リポジトリ。
class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(List<Book> books) : _books = List.of(books);

  final List<Book> _books;
  final List<String> removedIds = [];
  final List<String> addedIds = [];

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
  Future<void> addBook(Book book) async {
    addedIds.add(book.id);
    _books.add(book);
  }

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

class _FakeReviewRepository implements ReviewRepository {
  _FakeReviewRepository({List<Review> reviews = const []})
      : _reviews = List.of(reviews);

  final List<Review> _reviews;
  final List<String> deletedIds = [];
  final List<String> addedIds = [];

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => [
        for (final review in _reviews)
          if (review.bookId == bookId) review,
      ];

  @override
  Future<void> addReview(Review review) async {
    addedIds.add(review.id);
    _reviews.add(review);
  }

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {
    deletedIds.add(id);
    _reviews.removeWhere((review) => review.id == id);
  }
}

class _FakeNoteRepository implements BookNoteRepository {
  _FakeNoteRepository({List<BookNote> notes = const []})
      : _notes = List.of(notes);

  final List<BookNote> _notes;
  final List<String> deletedIds = [];
  final List<String> addedIds = [];

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async => [
        for (final note in _notes)
          if (note.bookId == bookId) note,
      ];

  @override
  Future<List<BookNote>> getAllNotes() async => List.of(_notes);

  @override
  Future<void> addNote(BookNote note) async {
    addedIds.add(note.id);
    _notes.add(note);
  }

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

Book _book(String id, {String? title}) => Book(
      id: id,
      title: title ?? '本 $id',
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

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_delete_confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('削除→Undo で本・レビュー・ノートが全部戻る', (tester) async {
    final books = _FakeBookRepository([_book(bookId, title: '戻る本')]);
    final reviews = _FakeReviewRepository(
      reviews: [_review('r1', bookId), _review('r2', bookId)],
    );
    final notes = _FakeNoteRepository(notes: [_note('n1', bookId)]);
    await pumpShelf(tester, books: books, reviews: reviews, notes: notes);

    await confirmDelete(tester);

    // 削除されている
    expect(books.removedIds, [bookId]);
    expect(reviews.deletedIds, ['r1', 'r2']);
    expect(notes.deletedIds, ['n1']);
    expect(find.text('戻る本'), findsNothing);
    expect(find.byKey(undoActionKey), findsOneWidget);

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();

    // 本・レビュー・ノートがすべて復元されている
    expect(await books.getBookById(bookId), isNotNull);
    expect(
      [for (final r in await reviews.getReviewsByBookId(bookId)) r.id],
      ['r1', 'r2'],
    );
    expect(
      [for (final n in await notes.getNotesByBookId(bookId)) n.id],
      ['n1'],
    );
    // 画面にも戻る（再読込経路が走る）
    expect(find.text('戻る本'), findsOneWidget);
  });

  testWidgets('Undo 直後に復元結果が1回だけ通知される', (tester) async {
    final books = _FakeBookRepository([_book(bookId)]);
    final reviews = _FakeReviewRepository(reviews: [_review('r1', bookId)]);
    final notes = _FakeNoteRepository(notes: [_note('n1', bookId)]);
    await pumpShelf(tester, books: books, reviews: reviews, notes: notes);

    await confirmDelete(tester);
    expect(find.text('「本 book-1」を削除しました'), findsOneWidget);

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();

    expect(find.text('元に戻しました（本1冊・書評1件・メモ1件）'), findsOneWidget);
    // 通知は1回だけ（非ブロッキング・追加ダイアログなし）
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Undo は二重復元できない（1回限り）', (tester) async {
    final books = _FakeBookRepository([_book(bookId)]);
    await pumpShelf(tester, books: books);

    await confirmDelete(tester);
    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();

    expect(books.addedIds, [bookId]);
    expect(find.byKey(undoActionKey), findsNothing);

    // 2回目はアクション自体が消えている＝追加復元なし
    expect(books.addedIds.length, 1);
  });

  testWidgets('確認ダイアログの文言・Key・キャンセル挙動は従来どおり', (tester) async {
    final books = _FakeBookRepository([_book(bookId, title: '削除対象本')]);
    final reviews = _FakeReviewRepository(reviews: [_review('r1', bookId)]);
    final notes = _FakeNoteRepository(notes: [_note('n1', bookId)]);
    await pumpShelf(tester, books: books, reviews: reviews, notes: notes);

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
    expect(dialogText, contains('書籍「削除対象本」を本棚から削除しますか？'));
    expect(dialogText, contains('書評1件'));
    expect(dialogText, contains('メモ1件'));
    expect(find.byKey(const Key('book_delete_confirm')), findsOneWidget);
    expect(find.byKey(const Key('book_delete_cancel')), findsOneWidget);
    // 押すまでは何も消えない
    expect(books.removedIds, isEmpty);

    await tester.tap(find.byKey(const Key('book_delete_cancel')));
    await tester.pumpAndSettle();

    expect(books.removedIds, isEmpty);
    expect(reviews.deletedIds, isEmpty);
    expect(notes.deletedIds, isEmpty);
    // キャンセルでは Undo SnackBar も出ない
    expect(find.byKey(undoActionKey), findsNothing);
    expect(find.text('削除対象本'), findsOneWidget);
  });
}
