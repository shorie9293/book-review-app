import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/presentation/backup_screen.dart';
import 'package:book_review_app/features/bookshelf/data/book_deletion_service.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 親探針: 眷属が個別にしか撃たない「画面→リポジトリ→実体の消滅」の合成と、
/// 孤児節が「本当に孤児だけを」扱う不変条件を独立に検証する。

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
      rating: 4,
      text: '書評 $id',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ $id',
      createdAt: DateTime.utc(2026, 3, 3),
    );

/// 実体を保持する本棚フェイク（削除で実体も消える）。
class _BookStore implements BookRepository {
  _BookStore(this.books);

  final List<Book> books;
  final List<String> removedIds = [];

  @override
  Future<List<Book>> getBooks() async => List.of(books);

  @override
  Future<Book?> getBookById(String id) async {
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async => books.add(book);

  @override
  Future<void> updateBook(Book book) async {}

  @override
  Future<void> removeBook(String id) async {
    removedIds.add(id);
    books.removeWhere((book) => book.id == id);
  }
}

/// 実体を保持するレビューフェイク。
class _ReviewStore implements ReviewRepository {
  _ReviewStore(this.reviews);

  final List<Review> reviews;
  final List<String> deletedIds = [];

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => [
        for (final review in reviews)
          if (review.bookId == bookId) review,
      ];

  @override
  Future<void> addReview(Review review) async => reviews.add(review);

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {
    deletedIds.add(id);
    reviews.removeWhere((review) => review.id == id);
  }
}

/// 実体を保持するメモフェイク。
class _NoteStore implements BookNoteRepository {
  _NoteStore(this.notes);

  final List<BookNote> notes;
  final List<String> deletedIds = [];

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async => [
        for (final note in notes)
          if (note.bookId == bookId) note,
      ];

  @override
  Future<List<BookNote>> getAllNotes() async => List.of(notes);

  @override
  Future<void> addNote(BookNote note) async => notes.add(note);

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<void> deleteNote(String id) async {
    deletedIds.add(id);
    notes.removeWhere((note) => note.id == id);
  }

  @override
  Future<void> deleteNotesByBookId(String bookId) async {
    notes.removeWhere((note) => note.bookId == bookId);
  }
}

void main() {
  late _BookStore bookStore;
  late _ReviewStore reviewStore;
  late _NoteStore noteStore;

  setUp(() {
    bookStore = _BookStore([_book('b1'), _book('b2')]);
    reviewStore = _ReviewStore([
      _review('r1', 'b1'),
      _review('r2', 'b1'),
      _review('r9', 'b2'),
    ]);
    noteStore = _NoteStore([
      _note('n1', 'b1'),
      _note('n9', 'b2'),
    ]);
  });

  Future<void> pumpShelf(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookshelfScreen(
          repository: bookStore,
          reviewRepository: reviewStore,
          noteRepository: noteStore,
          initialBooks: List.of(bookStore.books),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapDelete(WidgetTester tester, String bookId) async {
    final button = find.byKey(Key('status_button_$bookId'));
    // 対象書籍の行の削除ボタンまでスクロールしてから押す。
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final tile = find.ancestor(
      of: find.text('本 $bookId'),
      matching: find.byType(ListTile),
    );
    final deleteButton = find.descendant(
      of: tile,
      matching: find.byIcon(Icons.delete_outline),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
  }

  testWidgets('親探針1: 確定で本・レビュー・メモの実体が全て消える（合成）', (tester) async {
    await pumpShelf(tester);
    await tapDelete(tester, 'b1');

    expect(find.byKey(const Key('book_delete_confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('book_delete_confirm')));
    await tester.pumpAndSettle();

    expect(bookStore.books.map((b) => b.id).toList(), ['b2']);
    expect(reviewStore.reviews.map((r) => r.id).toList(), ['r9']);
    expect(noteStore.notes.map((n) => n.id).toList(), ['n9']);
  });

  testWidgets('親探針2: キャンセルなら本・レビュー・メモの実体は一切消えない', (tester) async {
    await pumpShelf(tester);
    await tapDelete(tester, 'b1');

    await tester.tap(find.byKey(const Key('book_delete_cancel')));
    await tester.pumpAndSettle();

    expect(bookStore.books.length, 2);
    expect(reviewStore.reviews.length, 3);
    expect(noteStore.notes.length, 2);
    expect(bookStore.removedIds, isEmpty);
    expect(reviewStore.deletedIds, isEmpty);
    expect(noteStore.deletedIds, isEmpty);
  });

  testWidgets('親探針3: 添付の内訳は実リポジトリの件数から作られる（メモのみの本で書評に触れない）',
      (tester) async {
    bookStore = _BookStore([_book('b3')]);
    reviewStore = _ReviewStore([]);
    noteStore = _NoteStore([_note('n3a', 'b3'), _note('n3b', 'b3')]);
    await pumpShelf(tester);
    await tapDelete(tester, 'b3');

    final contentText = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .join('\n');

    expect(contentText.contains('メモ2件'), isTrue, reason: contentText);
    expect(contentText.contains('書評'), isFalse, reason: contentText);
  });

  testWidgets('親探針4: 孤児節は「本のある」レビュー・メモを巻き込まない', (tester) async {
    // 孤児を1件ずつ混ぜる（本のあるレビュー2件・メモ1件は対象外）。
    reviewStore.reviews.add(_review('r-ghost', 'b-gone'));
    noteStore.notes.add(_note('n-ghost', 'b-gone'));

    final backup = InMemoryBackupRepository(
      books: bookStore.books,
      reviews: reviewStore.reviews,
      notes: noteStore.notes,
    );
    final service = BookDeletionService(
      deleteReviewById: (id) => reviewStore.deleteReview(id),
      deleteNoteById: (id) => noteStore.deleteNote(id),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          repository: backup,
          clipboardWriter: (value) async {},
          allReviewsLoader: () async => List.of(reviewStore.reviews),
          orphanCleanupService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('保存先を失ったデータ'), findsOneWidget);
    expect(find.textContaining('書評 1件'), findsOneWidget);

    final button = find.byKey(const Key('orphan_cleanup_button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    // 確認ダイアログの「削除」を押すまで実体は消えない。
    expect(reviewStore.reviews.any((r) => r.id == 'r-ghost'), isTrue);

    await tester.tap(find.widgetWithText(TextButton, '削除'));
    await tester.pumpAndSettle();

    // 孤児だけが消え、本に紐づくデータは残る。
    expect(reviewStore.reviews.map((r) => r.id).toSet(), {'r1', 'r2', 'r9'});
    expect(noteStore.notes.map((n) => n.id).toSet(), {'n1', 'n9'});
  });
}
