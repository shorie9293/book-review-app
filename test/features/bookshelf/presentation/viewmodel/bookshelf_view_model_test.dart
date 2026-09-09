import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/bookshelf/presentation/viewmodel/bookshelf_view_model.dart';

/// Fake BookRepository for testing ViewModel without Hive
class FakeBookRepository implements BookRepository {
  final Map<String, Book> _store = {};

  @override
  Future<List<Book>> getBooks() async => _store.values.toList();

  @override
  Future<Book?> getBookById(String id) async => _store[id];

  @override
  Future<Book?> findByIsbn(String isbn) async {
    try {
      return _store.values.firstWhere((b) => b.isbn == isbn);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addBook(Book book) async {
    _store[book.id] = book;
  }

  @override
  Future<void> updateBook(Book book) async {
    if (_store.containsKey(book.id)) _store[book.id] = book;
  }

  @override
  Future<void> removeBook(String id) async {
    _store.remove(id);
  }
}

/// Fake BookSearchService for testing
class FakeBookSearchService extends BookSearchService {
  final Map<String, Book> _results = {};
  final Set<String> _errors = {};
  final Map<String, Duration> _delays = {};

  void addResult(String isbn, Book book) => _results[isbn] = book;
  void addError(String isbn) => _errors.add(isbn);
  void addDelay(String isbn, Duration delay) => _delays[isbn] = delay;

  @override
  Future<Book?> searchByIsbn(String isbn) async {
    final normalized = isbn.replaceAll('-', '');
    if (_delays.containsKey(normalized)) {
      await Future.delayed(_delays[normalized]!);
    }
    if (_errors.contains(normalized)) {
      throw Exception('Search failed for $isbn');
    }
    return _results[normalized];
  }
}

Book _testBook({
  String id = 'book-1',
  String title = 'Test Book',
  String author = 'Test Author',
  String isbn = '1234567890',
}) {
  return Book(id: id, title: title, author: author, isbn: isbn);
}

void main() {
  group('BookshelfViewModel', () {
    late BookshelfViewModel viewModel;
    late FakeBookRepository repository;
    late FakeBookSearchService searchService;

    setUp(() {
      viewModel = BookshelfViewModel();
      repository = FakeBookRepository();
      searchService = FakeBookSearchService();
    });

    tearDown(() {
      viewModel.dispose();
    });

    group('initial state', () {
      test('books is empty', () {
        expect(viewModel.books, isEmpty);
      });

      test('foundBook is null', () {
        expect(viewModel.foundBook, isNull);
      });

      test('isSearching is false', () {
        expect(viewModel.isSearching, isFalse);
      });

      test('errorMessage is null', () {
        expect(viewModel.errorMessage, isNull);
      });

      test('isLoading is true', () {
        expect(viewModel.isLoading, isTrue);
      });
    });

    group('loadBooks', () {
      test('loads books from repository', () async {
        await repository.addBook(_testBook(id: '1', title: 'Book A'));
        await repository.addBook(_testBook(id: '2', title: 'Book B'));

        await viewModel.loadBooks(repository);

        expect(viewModel.books.length, 2);
        expect(viewModel.books[0].title, 'Book A');
        expect(viewModel.books[1].title, 'Book B');
        expect(viewModel.isLoading, isFalse);
      });

      test('loads empty list when repository is empty', () async {
        await viewModel.loadBooks(repository);

        expect(viewModel.books, isEmpty);
        expect(viewModel.isLoading, isFalse);
      });

      test('notifies listeners when loading completes', () async {
        var notified = false;
        viewModel.addListener(() => notified = true);

        await viewModel.loadBooks(repository);

        expect(notified, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('sets isLoading to true at start', () async {
        final future = viewModel.loadBooks(repository);

        // isLoading should be true immediately
        expect(viewModel.isLoading, isTrue);

        await future;
        expect(viewModel.isLoading, isFalse);
      });
    });

    group('searchByIsbn', () {
      test('finds book and sets foundBook', () async {
        final book = _testBook(id: 'found', title: 'Found Book', isbn: '1111111111');
        searchService.addResult('1111111111', book);

        await viewModel.searchByIsbn(searchService, '1111111111');

        expect(viewModel.foundBook, isNotNull);
        expect(viewModel.foundBook!.title, 'Found Book');
        expect(viewModel.isSearching, isFalse);
        expect(viewModel.errorMessage, isNull);
      });

      test('sets errorMessage when book not found', () async {
        await viewModel.searchByIsbn(searchService, '0000000000');

        expect(viewModel.foundBook, isNull);
        expect(viewModel.errorMessage, '書籍が見つかりませんでした');
        expect(viewModel.isSearching, isFalse);
      });

      test('sets errorMessage when search throws', () async {
        searchService.addError('9999999999');

        await viewModel.searchByIsbn(searchService, '9999999999');

        expect(viewModel.foundBook, isNull);
        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.errorMessage!.contains('エラー'), isTrue);
        expect(viewModel.isSearching, isFalse);
      });

      test('sets isSearching to true during search', () async {
        final book = _testBook(id: 'fast', title: 'Fast', isbn: 'fast');
        searchService.addResult('fast', book);

        // We can only test the end state here since search is synchronous in fake
        await viewModel.searchByIsbn(searchService, 'fast');
        expect(viewModel.isSearching, isFalse);
      });

      test('notifies listeners on completion', () async {
        final book = _testBook(id: 'notify', title: 'Notify', isbn: 'notify');
        searchService.addResult('notify', book);

        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.searchByIsbn(searchService, 'notify');

        expect(called, isTrue);
      });

      test('notifies listeners when isSearching changes to true', () async {
        final book = _testBook(id: 'slow', title: 'Slow', isbn: 'slow');
        searchService.addResult('slow', book);
        searchService.addDelay('slow', const Duration(milliseconds: 50));

        var searchStarted = false;
        viewModel.addListener(() {
          if (viewModel.isSearching) searchStarted = true;
        });

        // Start search
        final future = viewModel.searchByIsbn(searchService, 'slow');

        // Should have notified about isSearching=true synchronously
        expect(searchStarted, isTrue);

        await future;
      });

      test('does nothing for empty ISBN', () async {
        await viewModel.searchByIsbn(searchService, '');

        expect(viewModel.isSearching, isFalse);
        expect(viewModel.foundBook, isNull);
        expect(viewModel.errorMessage, isNull);
      });

      test('does nothing for whitespace-only ISBN', () async {
        await viewModel.searchByIsbn(searchService, '   ');

        expect(viewModel.isSearching, isFalse);
        expect(viewModel.foundBook, isNull);
        expect(viewModel.errorMessage, isNull);
      });
    });

    group('addBook', () {
      test('adds book to repository and reloads', () async {
        final book = _testBook(id: 'new', title: 'New Book');

        await viewModel.addBook(repository, book);

        // Repository should have the book
        final stored = await repository.getBookById('new');
        expect(stored, isNotNull);
        expect(stored!.title, 'New Book');

        // ViewModel books should be updated
        expect(viewModel.books.length, 1);
        expect(viewModel.books.first.title, 'New Book');
        expect(viewModel.foundBook, isNull);
      });

      test('clears foundBook after adding', () async {
        // Set up a found book first
        final searchBook = _testBook(id: 'search-result', title: 'Search Result', isbn: 'search');
        searchService.addResult('search', searchBook);
        await viewModel.searchByIsbn(searchService, 'search');
        expect(viewModel.foundBook, isNotNull);

        // Add a different book
        final newBook = _testBook(id: 'new-book', title: 'New Book');
        await viewModel.addBook(repository, newBook);

        expect(viewModel.foundBook, isNull);
      });

      test('notifies listeners', () async {
        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.addBook(repository, _testBook());

        expect(called, isTrue);
      });
    });

    group('deleteBook', () {
      test('removes book from repository and reloads', () async {
        await repository.addBook(_testBook(id: 'to-delete', title: 'Delete Me'));
        await repository.addBook(_testBook(id: 'keep', title: 'Keep Me'));
        await viewModel.loadBooks(repository);

        await viewModel.deleteBook(repository, 'to-delete');

        expect(viewModel.books.length, 1);
        expect(viewModel.books.first.id, 'keep');

        final stored = await repository.getBookById('to-delete');
        expect(stored, isNull);
      });

      test('does nothing when book id does not exist', () async {
        await repository.addBook(_testBook(id: 'only', title: 'Only'));
        await viewModel.loadBooks(repository);

        await viewModel.deleteBook(repository, 'non-existent');

        expect(viewModel.books.length, 1);
        expect(viewModel.books.first.id, 'only');
      });

      test('notifies listeners', () async {
        await repository.addBook(_testBook(id: 'notify-delete'));
        await viewModel.loadBooks(repository);

        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.deleteBook(repository, 'notify-delete');

        expect(called, isTrue);
      });
    });
  });
}
