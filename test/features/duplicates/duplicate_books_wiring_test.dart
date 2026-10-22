import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/duplicates/presentation/duplicate_books_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';

/// 固定の検索結果を返す検索サービス（通信しない）。
class FakeBookSearchService extends BookSearchService {
  FakeBookSearchService(this.result);

  final Book? result;

  @override
  Future<Book?> searchByIsbn(String isbn) async => result;
}

Book mk({
  required String id,
  required String title,
  required String isbn,
  DateTime? addedAt,
}) =>
    Book(
      id: id,
      title: title,
      author: '著者',
      isbn: isbn,
      addedAt: addedAt,
    );

void main() {
  Future<void> pumpShelf(
    WidgetTester tester, {
    required FakeBookRepository repository,
    List<Book> initialBooks = const [],
    BookSearchService? searchService,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: BookshelfScreen(
        repository: repository,
        searchService: searchService,
        initialBooks: initialBooks,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('重複ISBNがあればバナーが表示され、押下で重複整理画面へ遷移する', (tester) async {
    final books = [
      mk(id: 'a', title: '重複本A', isbn: '978-4-06-519123-4'),
      mk(id: 'b', title: '重複本B', isbn: '9784065191234'),
      mk(id: 'c', title: '別の本', isbn: '9781234567890'),
    ];
    final repository = FakeBookRepository(books);
    await pumpShelf(tester, repository: repository, initialBooks: books);

    expect(find.byKey(AppKeys.duplicateBanner), findsOneWidget);
    expect(find.text('重複した蔵書が 1組（2冊）あります'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.duplicateOpenButton));
    await tester.pumpAndSettle();

    expect(find.byType(DuplicateBooksScreen), findsOneWidget);
    expect(find.text('重複した蔵書'), findsOneWidget);
    expect(find.byKey(AppKeys.duplicateGroupCard('9784065191234')),
        findsOneWidget);
  });

  testWidgets('重複が無ければバナーは表示されない', (tester) async {
    final books = [
      mk(id: 'a', title: '本A', isbn: '9781111111111'),
      mk(id: 'b', title: '本B', isbn: '9782222222222'),
    ];
    final repository = FakeBookRepository(books);
    await pumpShelf(tester, repository: repository, initialBooks: books);

    expect(find.byKey(AppKeys.duplicateBanner), findsNothing);
    expect(find.byKey(AppKeys.duplicateOpenButton), findsNothing);
  });

  testWidgets('同一ISBNの書籍は本棚へ重複登録しない', (tester) async {
    final existing = mk(id: 'a', title: '既存本', isbn: '978-4-06-519123-4');
    final found = Book(
      id: '',
      title: '既存本',
      author: '著者',
      isbn: '9784065191234',
    );
    final repository = FakeBookRepository([existing]);
    await pumpShelf(
      tester,
      repository: repository,
      initialBooks: [existing],
      searchService: FakeBookSearchService(found),
    );

    await tester.enterText(
      find.byKey(const Key('isbn_search_field')),
      '9784065191234',
    );
    await tester.tap(find.byKey(const Key('isbn_search_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('本棚に追加'));
    await tester.pumpAndSettle();

    expect(find.text('「既存本」は既に本棚に登録されています'), findsOneWidget);
    expect(repository.addBookCalls, 0);
    expect(repository.books, hasLength(1));
  });
}
