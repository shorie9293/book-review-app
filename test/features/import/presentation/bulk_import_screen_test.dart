import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/import/presentation/bulk_import_screen.dart';

class _InMemoryBookRepository implements BookRepository {
  final Map<String, Book> books = {};

  @override
  Future<List<Book>> getBooks() async => books.values.toList();

  @override
  Future<Book?> getBookById(String id) async => books[id];

  @override
  Future<Book?> findByIsbn(String isbn) async {
    final normalized = isbn.replaceAll('-', '');
    for (final book in books.values) {
      if (book.isbn.replaceAll('-', '') == normalized) return book;
    }
    return null;
  }

  @override
  Future<void> addBook(Book book) async => books[book.id] = book;

  @override
  Future<void> updateBook(Book book) async => books[book.id] = book;

  @override
  Future<void> removeBook(String id) async => books.remove(id);
}

class _FakeSearchService extends BookSearchService {
  final Map<String, Book?> results;
  _FakeSearchService(this.results);

  @override
  Future<Book?> searchByIsbn(String isbn) async => results[isbn];
}

void main() {
  const isbnA = '9784774189079';
  const isbnB = '9784123456784';

  late _InMemoryBookRepository repository;
  late _FakeSearchService searchService;

  setUp(() {
    repository = _InMemoryBookRepository();
    searchService = _FakeSearchService({
      isbnA: Book(id: '', title: '吾輩は猫である', author: '夏目漱石', isbn: isbnA),
      isbnB: Book(id: '', title: '坊っちゃん', author: '夏目漱石', isbn: isbnB),
    });
  });

  Future<void> pumpScreen(WidgetTester tester, {VoidCallback? onImported}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BulkImportScreen(
          repository: repository,
          searchService: searchService,
          onImported: onImported,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('画面が描画され初期状態では取り込みボタンが無効', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('screen_bulk_import')), findsOneWidget);
    expect(find.byKey(const Key('bulk_import_text_field')), findsOneWidget);
    final runButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('bulk_import_run_button')),
    );
    expect(runButton.onPressed, isNull);
  });

  testWidgets('解析すると件数サマリと行が表示される', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('bulk_import_text_field')),
      '$isbnA\n$isbnA\ninvalid-isbn',
    );
    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();

    expect(find.byKey(const Key('bulk_import_summary')), findsOneWidget);
    expect(find.text('解析結果: 取込可 1 / 重複 1 / 不正 1'), findsOneWidget);
    expect(find.byKey(const Key('bulk_import_entry_0')), findsOneWidget);
    expect(find.byKey(const Key('bulk_import_entry_2')), findsOneWidget);
  });

  testWidgets('取り込むと蔵書に追加され結果カードが表示される', (tester) async {
    var imported = false;
    await pumpScreen(tester, onImported: () => imported = true);

    await tester.enterText(
      find.byKey(const Key('bulk_import_text_field')),
      '$isbnA\n$isbnB',
    );
    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bulk_import_run_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.books.length, 2);
    expect(imported, isTrue);
    expect(find.byKey(const Key('bulk_import_report')), findsOneWidget);
    expect(find.text('追加 2 冊'), findsOneWidget);
  });

  testWidgets('空入力の解析ではエラーメッセージを表示する', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();

    expect(find.byKey(const Key('bulk_import_error')), findsOneWidget);
    expect(find.byKey(const Key('bulk_import_summary')), findsNothing);
  });

  testWidgets('CSVモードに切り替えて取り込める', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('CSV'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('bulk_import_text_field')),
      'isbn,title,author\n$isbnA,CSVタイトル,CSV著者\n',
    );
    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();

    expect(find.text('解析結果: 取込可 1 / 重複 0 / 不正 0'), findsOneWidget);
    expect(find.textContaining('CSVタイトル'), findsWidgets);
  });

  testWidgets('リセットで解析結果が消える', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('bulk_import_text_field')), isbnA);
    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();
    expect(find.byKey(const Key('bulk_import_summary')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bulk_import_reset_button')));
    await tester.pump();

    expect(find.byKey(const Key('bulk_import_summary')), findsNothing);
  });

  testWidgets('既存蔵書のISBNはスキップされる', (tester) async {
    await repository.addBook(
      Book(id: 'existing', title: '既存', author: '著者', isbn: isbnA),
    );
    await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('bulk_import_text_field')), isbnA);
    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bulk_import_run_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('登録済（スキップ） 1 冊'), findsOneWidget);
    expect(repository.books.length, 1);
  });
}
