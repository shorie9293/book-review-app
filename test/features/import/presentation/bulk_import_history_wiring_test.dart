import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/import/data/import_history_repository.dart';
import 'package:book_review_app/features/import/domain/import_history_entry.dart';
import 'package:book_review_app/features/import/presentation/bulk_import_screen.dart';
import 'package:book_review_app/features/import/presentation/import_history_screen.dart';

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

/// save で必ず例外を投げる壊れた保存先（取込の成否に影響しないことの確認用）。
class _ThrowingImportHistoryRepository implements ImportHistoryRepository {
  @override
  Future<List<ImportHistoryEntry>> load() async => throw StateError('load失敗');

  @override
  Future<void> save(List<ImportHistoryEntry> entries) async =>
      throw StateError('save失敗');
}

void main() {
  const isbnA = '9784774189079';
  const isbnB = '9784123456784';
  const isbnMissing = '9784000000000';

  late _InMemoryBookRepository bookRepository;
  late _FakeSearchService searchService;
  late InMemoryImportHistoryRepository historyRepository;
  final fixedNow = DateTime(2026, 6, 10, 9, 15);

  setUp(() {
    bookRepository = _InMemoryBookRepository();
    searchService = _FakeSearchService({
      isbnA: Book(id: '', title: '吾輩は猫である', author: '夏目漱石', isbn: isbnA),
      isbnB: Book(id: '', title: '坊っちゃん', author: '夏目漱石', isbn: isbnB),
    });
    historyRepository = InMemoryImportHistoryRepository();
  });

  Future<void> pumpBulkImport(
    WidgetTester tester, {
    ImportHistoryRepository? history,
    VoidCallback? onImported,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BulkImportScreen(
          repository: bookRepository,
          searchService: searchService,
          onImported: onImported,
          historyRepository: history,
          clock: () => fixedNow,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> runImport(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const Key('bulk_import_text_field')),
      text,
    );
    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bulk_import_run_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('取込を実行すると履歴が保存され、同じ repository の履歴画面に表示される', (tester) async {
    await pumpBulkImport(tester, history: historyRepository);
    await runImport(tester, '$isbnA\n$isbnB');

    // 試練①: save まで到達している
    final saved = await historyRepository.load();
    expect(saved, hasLength(1));
    expect(saved.single.addedCount, 2);
    expect(saved.single.mode, 'ISBNリスト');
    expect(saved.single.importedAt, fixedNow);
    expect(saved.single.sampleIsbns, [isbnA, isbnB]);
    expect(saved.single.id.trim().isNotEmpty, isTrue);

    // 合成の不変条件: 同じ repository を渡した履歴画面に表示される
    await tester.pumpWidget(
      MaterialApp(home: ImportHistoryScreen(repository: historyRepository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('import_history_row_${saved.single.id}')),
      findsOneWidget,
    );
    expect(find.textContaining('追加2'), findsWidgets);
  });

  testWidgets('履歴ボタンから履歴画面へ遷移できる', (tester) async {
    await pumpBulkImport(tester, history: historyRepository);
    await runImport(tester, isbnA);

    await tester.tap(find.byKey(const Key('bulk_import_history_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen_import_history')), findsOneWidget);
    expect(find.byKey(const Key('import_history_empty')), findsNothing);
    expect(find.textContaining(isbnA), findsNothing);
  });

  testWidgets('処理対象が無い（report が得られない）時は記録しない', (tester) async {
    await pumpBulkImport(tester, history: historyRepository);

    // 不正な ISBN のみ → 解析は空になり report は生成されない
    await tester.enterText(
      find.byKey(const Key('bulk_import_text_field')),
      'invalid-isbn',
    );
    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();

    final runButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('bulk_import_run_button')),
    );
    expect(runButton.onPressed, isNull);

    expect(await historyRepository.load(), isEmpty);
  });

  testWidgets('historyRepository が null なら履歴ボタンを出さない（後方互換）', (tester) async {
    await pumpBulkImport(tester);

    expect(
      find.byKey(const Key('bulk_import_history_button')),
      findsNothing,
    );

    // 取込自体は従来どおり成功する
    await runImport(tester, isbnA);
    expect(bookRepository.books, hasLength(1));
    expect(find.byKey(const Key('bulk_import_report')), findsOneWidget);
  });

  testWidgets('履歴の保存に失敗しても取込は成功のまま', (tester) async {
    var imported = false;
    await pumpBulkImport(
      tester,
      history: _ThrowingImportHistoryRepository(),
      onImported: () => imported = true,
    );

    await runImport(tester, isbnA);

    expect(bookRepository.books, hasLength(1));
    expect(imported, isTrue);
    expect(find.byKey(const Key('bulk_import_report')), findsOneWidget);
  });

  testWidgets('書誌なしの行も履歴に記録される', (tester) async {
    await pumpBulkImport(tester, history: historyRepository);
    await runImport(tester, isbnMissing);

    final saved = await historyRepository.load();
    expect(saved, hasLength(1));
    expect(saved.single.notFoundCount, 1);
    expect(saved.single.outcomeLabel, '完了');
  });
}
