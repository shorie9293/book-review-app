import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/import/presentation/viewmodel/bulk_import_view_model.dart';

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

  Book book(String isbn) => Book(id: '', title: 'T', author: 'A', isbn: isbn);

  test('初期状態はプレビュー無し・ISBNリストモード', () {
    final vm = BulkImportViewModel();
    expect(vm.mode, BulkImportMode.isbnList);
    expect(vm.preview, isNull);
    expect(vm.report, isNull);
    expect(vm.isImporting, isFalse);
  });

  test('parseがプレビューを設定する', () {
    final vm = BulkImportViewModel();
    vm.parse('$isbnA\n$isbnB');
    expect(vm.preview, isNotNull);
    expect(vm.preview!.validCount, 2);
    expect(vm.errorMessage, isNull);
  });

  test('空入力の解析はエラーメッセージを設定する', () {
    final vm = BulkImportViewModel();
    vm.parse('   ');
    expect(vm.preview, isNull);
    expect(vm.errorMessage, isNotNull);
  });

  test('モード切替でプレビューが破棄される', () {
    final vm = BulkImportViewModel();
    vm.parse(isbnA);
    expect(vm.preview, isNotNull);
    vm.setMode(BulkImportMode.csv);
    expect(vm.preview, isNull);
    expect(vm.mode, BulkImportMode.csv);
  });

  test('CSVモードで解析できる', () {
    final vm = BulkImportViewModel();
    vm.setMode(BulkImportMode.csv);
    vm.parse('isbn,title\n$isbnA,吾輩は猫である\n');
    expect(vm.preview!.validCount, 1);
    expect(vm.preview!.entries.single.title, '吾輩は猫である');
  });

  test('runImportが蔵書へ登録し報告を返す', () async {
    final vm = BulkImportViewModel();
    final repo = _InMemoryBookRepository();
    final search = _FakeSearchService({
      isbnA: book(isbnA),
      isbnB: book(isbnB),
    });
    vm.parse('$isbnA\n$isbnB');

    await vm.runImport(repository: repo, searchService: search);

    expect(vm.report, isNotNull);
    expect(vm.report!.addedCount, 2);
    expect(repo.books.length, 2);
    expect(vm.isImporting, isFalse);
  });

  test('取り込み進捗を進捗カウンタに反映する', () async {
    final vm = BulkImportViewModel();
    final repo = _InMemoryBookRepository();
    final search = _FakeSearchService({isbnA: book(isbnA), isbnB: book(isbnB)});
    vm.parse('$isbnA\n$isbnB');

    await vm.runImport(repository: repo, searchService: search);

    expect(vm.progressDone, 2);
    expect(vm.progressTotal, 2);
  });

  test('取込可0件ではrunImportが何もしない', () async {
    final vm = BulkImportViewModel();
    final repo = _InMemoryBookRepository();
    vm.parse('bad-isbn');

    await vm.runImport(repository: repo, searchService: _FakeSearchService({}));

    expect(vm.report, isNull);
    expect(repo.books, isEmpty);
  });

  test('resetが全状態を初期化する', () async {
    final vm = BulkImportViewModel();
    final repo = _InMemoryBookRepository();
    vm.parse(isbnA);
    await vm.runImport(
      repository: repo,
      searchService: _FakeSearchService({isbnA: book(isbnA)}),
    );
    vm.reset();
    expect(vm.preview, isNull);
    expect(vm.report, isNull);
    expect(vm.isImporting, isFalse);
  });

  test('解析結果はImportEntryStatusを反映する', () {
    final vm = BulkImportViewModel();
    vm.parse('$isbnA\n$isbnA\nbad');
    expect(vm.preview!.validCount, 1);
    expect(vm.preview!.duplicateCount, 1);
    expect(vm.preview!.invalidCount, 1);
  });
}
