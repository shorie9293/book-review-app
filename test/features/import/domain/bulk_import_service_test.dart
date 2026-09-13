import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/import/domain/bulk_import_parser.dart';
import 'package:book_review_app/features/import/domain/bulk_import_service.dart';

/// メモリ上の BookRepository（Hive に触れず試練を完結させる）
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
  Future<void> addBook(Book book) async {
    books[book.id] = book;
  }

  @override
  Future<void> updateBook(Book book) async {
    if (books.containsKey(book.id)) books[book.id] = book;
  }

  @override
  Future<void> removeBook(String id) async {
    books.remove(id);
  }
}

/// 固定の書誌を返す BookSearchService
class _FakeSearchService extends BookSearchService {
  final Map<String, Book?> results;
  final Set<String> throwing = {};
  int callCount = 0;

  _FakeSearchService(this.results);

  @override
  Future<Book?> searchByIsbn(String isbn) async {
    callCount++;
    if (throwing.contains(isbn)) throw Exception('network down');
    return results[isbn];
  }
}

Book _book({
  required String isbn,
  String title = 'タイトル',
  String author = '著者',
  String? publisher,
}) {
  return Book(
    id: '',
    title: title,
    author: author,
    isbn: isbn,
    publisher: publisher,
  );
}

void main() {
  const isbnA = '9784774189079';
  const isbnB = '9784123456784';
  const isbnC = '4123456782';

  group('BulkImportService.run', () {
    test('書誌が見つかったISBNを新規追加する', () async {
      final repo = _InMemoryBookRepository();
      final search = _FakeSearchService({
        isbnA: _book(isbn: isbnA, title: '吾輩は猫である', author: '夏目漱石'),
        isbnB: _book(isbn: isbnB, title: '坊っちゃん', author: '夏目漱石'),
      });
      final service = BulkImportService(
        repository: repo,
        searchService: search,
        idGenerator: () => 'id-${repo.books.length}',
      );

      final report = await service.run(BulkImportParser.parseIsbnList('$isbnA\n$isbnB'));

      expect(report.addedCount, 2);
      expect(repo.books.length, 2);
      final added = repo.books.values.firstWhere((b) => b.isbn == isbnA);
      expect(added.title, '吾輩は猫である');
      expect(added.id, isNotEmpty);
    });

    test('既に蔵書にあるISBNはスキップし重複登録しない', () async {
      final repo = _InMemoryBookRepository();
      await repo.addBook(Book(id: 'existing', title: '既存', author: '著者', isbn: isbnA));
      final search = _FakeSearchService({isbnA: _book(isbn: isbnA)});
      final service = BulkImportService(repository: repo, searchService: search);

      final report = await service.run(BulkImportParser.parseIsbnList(isbnA));

      expect(report.skippedCount, 1);
      expect(report.addedCount, 0);
      expect(search.callCount, 0, reason: '既存書の書誌検索は呼ばれない');
      expect(repo.books.length, 1);
    });

    test('書誌が見つからない場合はnotFoundとして記録する', () async {
      final repo = _InMemoryBookRepository();
      final search = _FakeSearchService({isbnA: null});
      final service = BulkImportService(repository: repo, searchService: search);

      final report = await service.run(BulkImportParser.parseIsbnList(isbnA));

      expect(report.notFoundCount, 1);
      expect(report.addedCount, 0);
      expect(repo.books, isEmpty);
    });

    test('検索例外時はfailedとして記録し他の行は継続する', () async {
      final repo = _InMemoryBookRepository();
      final search = _FakeSearchService({
        isbnA: _book(isbn: isbnA),
        isbnB: _book(isbn: isbnB),
      })..throwing.add(isbnA);
      final service = BulkImportService(repository: repo, searchService: search);

      final report = await service.run(BulkImportParser.parseIsbnList('$isbnA\n$isbnB'));

      expect(report.failedCount, 1);
      expect(report.addedCount, 1);
      expect(repo.books.length, 1);
    });

    test('不正・重複行は処理対象から除外する', () async {
      final repo = _InMemoryBookRepository();
      final search = _FakeSearchService({isbnA: _book(isbn: isbnA)});
      final service = BulkImportService(repository: repo, searchService: search);

      final report = await service.run(
        BulkImportParser.parseIsbnList('$isbnA\n$isbnA\n9999999999999'),
      );

      expect(report.processedCount, 1);
      expect(report.addedCount, 1);
    });

    test('CSVで指定された書名・著者を検索結果より優先する', () async {
      final repo = _InMemoryBookRepository();
      final search = _FakeSearchService({
        isbnA: _book(isbn: isbnA, title: 'API取得タイトル', author: 'API著者'),
      });
      final service = BulkImportService(
        repository: repo,
        searchService: search,
        idGenerator: () => 'fixed-id',
      );

      final report = await service.run(
        BulkImportParser.parseCsv('isbn,title,author\n$isbnA,CSVタイトル,CSV著者\n'),
      );

      expect(report.addedCount, 1);
      final added = repo.books['fixed-id']!;
      expect(added.title, 'CSVタイトル');
      expect(added.author, 'CSV著者');
    });

    test('ISBN-10も取り込める', () async {
      final repo = _InMemoryBookRepository();
      final search = _FakeSearchService({isbnC: _book(isbn: isbnC)});
      final service = BulkImportService(repository: repo, searchService: search);

      final report = await service.run(BulkImportParser.parseIsbnList(isbnC));

      expect(report.addedCount, 1);
      expect(repo.books.values.single.isbn, isbnC);
    });

    test('onProgressが処理件数を通知する', () async {
      final repo = _InMemoryBookRepository();
      final search = _FakeSearchService({
        isbnA: _book(isbn: isbnA),
        isbnB: _book(isbn: isbnB),
      });
      final service = BulkImportService(repository: repo, searchService: search);
      final progress = <String>[];

      await service.run(
        BulkImportParser.parseIsbnList('$isbnA\n$isbnB'),
        onProgress: (done, total) => progress.add('$done/$total'),
      );

      expect(progress, ['1/2', '2/2']);
    });

    test('取り込み対象が無い場合は空の報告を返す', () async {
      final repo = _InMemoryBookRepository();
      final service = BulkImportService(
        repository: repo,
        searchService: _FakeSearchService({}),
      );

      final report = await service.run(BulkImportParser.parseIsbnList('9999999999999'));

      expect(report.isEmpty, isTrue);
      expect(report.addedCount, 0);
    });
  });
}
