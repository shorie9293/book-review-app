import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/import/data/import_history_repository.dart';
import 'package:book_review_app/features/import/domain/import_history_entry.dart';
import 'package:book_review_app/features/import/domain/import_history_service.dart';
import 'package:book_review_app/features/import/presentation/bulk_import_screen.dart';
import 'package:book_review_app/features/import/presentation/import_history_screen.dart';

/// 親探針（合成の不変条件）。眷属の個別試練では撃たれない「画面をまたぐ」性質のみを撃つ。

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

  late _InMemoryBookRepository bookRepository;
  late _FakeSearchService searchService;
  late InMemoryImportHistoryRepository historyRepository;
  late DateTime clockNow;

  setUp(() {
    bookRepository = _InMemoryBookRepository();
    searchService = _FakeSearchService({
      isbnA: Book(id: '', title: '吾輩は猫である', author: '夏目漱石', isbn: isbnA),
      isbnB: Book(id: '', title: '坊っちゃん', author: '夏目漱石', isbn: isbnB),
    });
    historyRepository = InMemoryImportHistoryRepository();
    clockNow = DateTime(2026, 6, 10, 9, 15);
  });

  Future<void> pumpBulkImport(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BulkImportScreen(
          repository: bookRepository,
          searchService: searchService,
          historyRepository: historyRepository,
          clock: () => clockNow,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> runImport(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('bulk_import_text_field')), text);
    await tester.tap(find.byKey(const Key('bulk_import_parse_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bulk_import_run_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('探針1: 2回取込むと履歴2件が新しい順で画面に出る（appendの順序が画面経由で正しい）',
      (tester) async {
    await pumpBulkImport(tester);

    await runImport(tester, isbnA);
    clockNow = DateTime(2026, 6, 10, 10, 30);
    await runImport(tester, isbnB);

    final saved = await historyRepository.load();
    expect(saved, hasLength(2), reason: '2回の取込で2件記録される');
    final sorted = ImportHistoryService.sortNewestFirst(saved);
    expect(sorted.first.importedAt, DateTime(2026, 6, 10, 10, 30),
        reason: '新しい取込が先頭');

    // 同じリポジトリを見る履歴画面で、その並びがそのまま可視化されること
    await tester.pumpWidget(
      MaterialApp(
        home: ImportHistoryScreen(
          repository: historyRepository,
          clock: () => clockNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import_history_empty')), findsNothing);
    final rows = tester
        .widgetList(
          find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>)
                  .value
                  .startsWith('import_history_row_')),
        )
        .toList();
    expect(rows.length, 2, reason: '履歴画面に2行');
    final firstRowId = (rows.first.key as ValueKey<String>).value;
    expect(firstRowId, 'import_history_row_${sorted.first.id}',
        reason: '画面の先頭行はサービスが定めた最新エントリ');
  });

  testWidgets('探針2: 上限200件は画面経由の追記でも効く', (tester) async {
    // 既に上限（200件）まで積まれている状態（新しい順で保持）から1件追記する
    final existing = List<ImportHistoryEntry>.generate(
      ImportHistoryService.maxEntries,
      (i) => ImportHistoryEntry(
        id: i == ImportHistoryService.maxEntries - 1 ? 'old-oldest' : 'old-$i',
        importedAt:
            DateTime(2026, 1, 1).add(Duration(minutes: ImportHistoryService.maxEntries - i)),
        mode: 'ISBNリスト',
        addedCount: 1,
        skippedCount: 0,
        notFoundCount: 0,
        failedCount: 0,
        sampleIsbns: const [],
      ),
    );
    historyRepository = InMemoryImportHistoryRepository(existing);

    await pumpBulkImport(tester);
    await runImport(tester, isbnA);

    final saved = await historyRepository.load();
    expect(saved, hasLength(ImportHistoryService.maxEntries),
        reason: '200件を超えない');
    expect(saved.any((e) => e.id == 'old-oldest'), isFalse,
        reason: '末尾（最古）の1件が切り捨てられる');
    expect(saved.first.addedCount, 1, reason: '新しい取込が先頭に残る');
  });

  testWidgets('探針3: 画面を作り直しても同じ保存先から履歴が復元される（永続性の合成）',
      (tester) async {
    await pumpBulkImport(tester);
    await runImport(tester, isbnA);

    // アプリ再起動相当＝widget ツリーを破棄して新しいインスタンスで開き直す
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: ImportHistoryScreen(
          repository: historyRepository,
          clock: () => clockNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import_history_empty')), findsNothing);
    expect(find.textContaining('追加1'), findsWidgets,
        reason: '再起動後も取込結果が残る');
  });
}
