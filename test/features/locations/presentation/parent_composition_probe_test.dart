import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/locations/domain/shelf_location_service.dart';

/// 状態を持つフェイク（保存→別インスタンスでの復元を合成検証するため）。
class InMemoryBookRepository implements BookRepository {
  InMemoryBookRepository([List<Book> seed = const []]) {
    for (final book in seed) {
      _store[book.id] = book;
    }
  }

  final Map<String, Book> _store = {};

  Book? stored(String id) => _store[id];

  @override
  Future<List<Book>> getBooks() async => _store.values.toList();

  @override
  Future<Book?> getBookById(String id) async => _store[id];

  @override
  Future<Book?> findByIsbn(String isbn) async {
    for (final book in _store.values) {
      if (book.isbn == isbn) return book;
    }
    return null;
  }

  @override
  Future<void> addBook(Book book) async => _store[book.id] = book;

  @override
  Future<void> updateBook(Book book) async => _store[book.id] = book;

  @override
  Future<void> removeBook(String id) async => _store.remove(id);
}

class EmptyReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => const [];

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

class EmptyNoteRepository implements BookNoteRepository {
  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async => const [];

  @override
  Future<List<BookNote>> getAllNotes() async => const [];

  @override
  Future<void> addNote(BookNote note) async {}

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> deleteNotesByBookId(String bookId) async {}
}

Book book(String id, String title, {String? location}) => Book(
      id: id,
      title: title,
      author: '著者$id',
      isbn: 'isbn$id',
      location: location,
    );

Widget detailApp(Book target, BookRepository repository) => MaterialApp(
      home: BookDetailScreen(
        book: target,
        bookRepository: repository,
        reviewRepository: EmptyReviewRepository(),
        noteRepository: EmptyNoteRepository(),
      ),
    );

void main() {
  testWidgets('親探針1: 画面で保存した所在がリポジトリへ到達し、別インスタンスの画面で復元される',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = InMemoryBookRepository([book('b1', '技術書')]);
    await tester.pumpWidget(detailApp(repository.stored('b1')!, repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(AppKeys.locationEditButton));
    await tester.tap(find.byKey(AppKeys.locationEditButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.locationInput), '居間の本棚 2段目');
    await tester.tap(find.byKey(AppKeys.locationSave));
    await tester.pumpAndSettle();

    // 永続化に到達したか（state 更新だけで終わっていないか）
    expect(repository.stored('b1')!.location, '居間の本棚 2段目');

    // 再起動相当: 同じリポジトリから読み直した本で新しい画面を作る
    final reloaded = await repository.getBookById('b1');
    await tester.pumpWidget(detailApp(reloaded!, repository));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.locationValue), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(AppKeys.locationValue)).data,
      '居間の本棚 2段目',
    );
  });

  testWidgets('親探針2: 全角入力は正規化されて保存され、同じ正規化キーで絞り込める',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = InMemoryBookRepository([book('b1', '全角の本')]);
    await tester.pumpWidget(detailApp(repository.stored('b1')!, repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(AppKeys.locationEditButton));
    await tester.tap(find.byKey(AppKeys.locationEditButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.locationInput), '本棚Ａ');
    await tester.tap(find.byKey(AppKeys.locationSave));
    await tester.pumpAndSettle();

    final saved = repository.stored('b1')!;
    expect(saved.location, '本棚A');
    expect(ShelfLocationService.locationOf(saved), '本棚A');

    final books = [
      book('b1', '全角の本', location: saved.location),
      book('b2', '別の本', location: '本棚B'),
    ];
    expect(
      ShelfLocationService.filterByLocations(books, {'本棚Ａ'}),
      hasLength(1),
    );
  });

  testWidgets('親探針3: 本棚の所在絞り込みがサービスの絞込結果・件数表示と一致する',
      (tester) async {
    final books = [
      book('b1', '居間の技術書', location: '居間の本棚 2段目'),
      book('b2', '居間の小説', location: '居間の本棚 1段目'),
      book('b3', '寝室の本', location: '寝室の棚'),
      book('b4', '所在不明の本'),
    ];
    final repository = InMemoryBookRepository(books);
    await tester.pumpWidget(MaterialApp(
      home: BookshelfScreen(repository: repository, initialBooks: books),
    ));
    await tester.pumpAndSettle();

    // 期待値はサービスから独立に算出する
    final expected = ShelfLocationService.filterByLocations(books, {'居間の本棚 2段目'});
    expect(expected, hasLength(1));

    final chip = find.byKey(AppKeys.locationFilterChip('居間の本棚 2段目'));
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('1 / 4 冊'), findsOneWidget);
    expect(find.text('居間の技術書'), findsWidgets);
    expect(find.text('居間の小説'), findsNothing);
    expect(find.text('所在不明の本'), findsNothing);

    // サービスと画面が同じ部分集合を見ていること
    final query = const LibraryQuery().copyWith(locations: {'居間の本棚 2段目'});
    expect(
      LibraryQueryService.apply(books, query).map((b) => b.id).toList(),
      expected.map((b) => b.id).toList(),
    );
  });

  testWidgets('親探針4: 「所在を消す」で永続値が null に戻り、画面も未設定表示へ戻る',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = InMemoryBookRepository([
      book('b1', '所在ありの本', location: '居間の本棚 2段目'),
    ]);
    await tester.pumpWidget(detailApp(repository.stored('b1')!, repository));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.locationValue), findsOneWidget);

    await tester.ensureVisible(find.byKey(AppKeys.locationEditButton));
    await tester.tap(find.byKey(AppKeys.locationEditButton));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.locationClear), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.locationClear));
    await tester.pumpAndSettle();

    expect(repository.stored('b1')!.location, isNull);
    expect(find.byKey(AppKeys.locationValue), findsNothing);
    expect(find.text('所在未設定'), findsOneWidget);
  });
}
