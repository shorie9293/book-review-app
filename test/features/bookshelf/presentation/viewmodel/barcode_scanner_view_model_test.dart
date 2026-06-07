import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/bookshelf/presentation/viewmodel/barcode_scanner_view_model.dart';

/// Fake BookSearchService for testing
class FakeBarcodeSearchService extends BookSearchService {
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
  String id = '',
  String title = 'Test Book',
  String author = 'Test Author',
  String isbn = '1234567890',
}) {
  return Book(id: id, title: title, author: author, isbn: isbn);
}

void main() {
  group('BarcodeScannerViewModel', () {
    late BarcodeScannerViewModel viewModel;
    late FakeBarcodeSearchService searchService;

    setUp(() {
      viewModel = BarcodeScannerViewModel();
      searchService = FakeBarcodeSearchService();
    });

    tearDown(() {
      viewModel.dispose();
    });

    group('initial state', () {
      test('isScanning is false', () {
        expect(viewModel.isScanning, isFalse);
      });

      test('lastScannedIsbn is null', () {
        expect(viewModel.lastScannedIsbn, isNull);
      });

      test('lastScanTime is null', () {
        expect(viewModel.lastScanTime, isNull);
      });

      test('scannedBook is null', () {
        expect(viewModel.scannedBook, isNull);
      });

      test('errorMessage is null', () {
        expect(viewModel.errorMessage, isNull);
      });
    });

    group('searchBook', () {
      test('finds book and sets scannedBook', () async {
        final book = _testBook(title: 'Found via scan', isbn: '1111111111');
        searchService.addResult('1111111111', book);

        await viewModel.searchBook(searchService, '1111111111');

        expect(viewModel.scannedBook, isNotNull);
        expect(viewModel.scannedBook!.title, 'Found via scan');
        expect(viewModel.isScanning, isFalse);
        expect(viewModel.lastScannedIsbn, '1111111111');
        expect(viewModel.lastScanTime, isNotNull);
      });

      test('returns book not found state when null', () async {
        await viewModel.searchBook(searchService, '0000000000');

        expect(viewModel.scannedBook, isNull);
        expect(viewModel.isScanning, isFalse);
        expect(viewModel.notFoundMessage, '書籍が見つかりませんでした');
      });

      test('handles search error gracefully', () async {
        searchService.addError('9999999999');

        await viewModel.searchBook(searchService, '9999999999');

        expect(viewModel.scannedBook, isNull);
        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.errorMessage!.contains('エラー'), isTrue);
        expect(viewModel.isScanning, isFalse);
      });

      test('sets isScanning to true during search', () async {
        final book = _testBook(isbn: 'delayed');
        searchService.addResult('delayed', book);
        searchService.addDelay('delayed', const Duration(milliseconds: 100));

        // Start search but don't await - isScanning should be true immediately
        final future = viewModel.searchBook(searchService, 'delayed');

        // Check that isScanning is set synchronously
        expect(viewModel.isScanning, isTrue);

        await future;
        expect(viewModel.isScanning, isFalse);
      });

      test('notifies listeners on completion', () async {
        final book = _testBook(isbn: 'notify');
        searchService.addResult('notify', book);

        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.searchBook(searchService, 'notify');

        expect(called, isTrue);
      });
    });

    group('debounce', () {
      test('records lastScannedIsbn and lastScanTime after scan', () async {
        final book = _testBook(isbn: 'debounce-isbn');
        searchService.addResult('debounce-isbn', book);

        final before = DateTime(2024, 1, 1); // far in the past
        await viewModel.searchBook(searchService, 'debounce-isbn');

        expect(viewModel.lastScannedIsbn, 'debounce-isbn');
        expect(viewModel.lastScanTime, isNotNull);
        // lastScanTime should be recent (after the test started)
        expect(
          viewModel.lastScanTime!.isAfter(before),
          isTrue,
        );
      });

      test('isDuplicate correctly detects same ISBN within window', () async {
        final book = _testBook(isbn: 'dup-isbn');
        searchService.addResult('dup-isbn', book);

        await viewModel.searchBook(searchService, 'dup-isbn');

        // Without time passing, same ISBN should be detected as duplicate
        expect(viewModel.isDuplicate('dup-isbn'), isTrue);
      });

      test('isDuplicate returns false for different ISBN', () {
        // Set up a previous scan
        viewModel.lastScannedIsbn = 'old-isbn';
        viewModel.lastScanTime = DateTime.now();

        expect(viewModel.isDuplicate('new-isbn'), isFalse);
      });

      test('isDuplicate returns false when no previous scan', () {
        expect(viewModel.isDuplicate('any-isbn'), isFalse);
      });

      test('isDuplicate returns false when lastScannedIsbn is null', () {
        // lastScanTime is set but lastScannedIsbn is null
        viewModel.lastScanTime = DateTime.now();

        expect(viewModel.isDuplicate('some-isbn'), isFalse);
      });

      test('isDuplicate returns false when lastScanTime is null', () {
        // lastScannedIsbn is set but lastScanTime is null
        viewModel.lastScannedIsbn = 'some-isbn';

        expect(viewModel.isDuplicate('some-isbn'), isFalse);
      });

      test('isDuplicate returns false when debounce period has expired', () async {
        final book = _testBook(isbn: 'expired-isbn');
        searchService.addResult('expired-isbn', book);

        await viewModel.searchBook(searchService, 'expired-isbn');
        expect(viewModel.isDuplicate('expired-isbn'), isTrue);

        // Simulate time passing beyond debounce window
        viewModel.lastScanTime =
            DateTime.now().subtract(const Duration(seconds: 3));

        expect(viewModel.isDuplicate('expired-isbn'), isFalse);
      });
    });

    group('confirm/cancel', () {
      test('confirmBook sets confirmedBook and returns true', () async {
        final book = _testBook(isbn: 'confirmlsbn');
        searchService.addResult('confirmlsbn', book);
        await viewModel.searchBook(searchService, 'confirmlsbn');

        final result = await viewModel.confirmBook();

        expect(result, isTrue);
        expect(viewModel.confirmedBook, isNotNull);
        expect(viewModel.confirmedBook!.isbn, 'confirmlsbn');
      });

      test('cancelScan resumes scanning', () async {
        final book = _testBook(isbn: 'cancellsbn');
        searchService.addResult('cancellsbn', book);
        await viewModel.searchBook(searchService, 'cancellsbn');

        viewModel.cancelScan();

        expect(viewModel.isScanning, isFalse);
        expect(viewModel.scannedBook, isNull);
      });

      test('resumeScanning clears state and sets isScanning to false', () {
        viewModel.resumeScanning();

        expect(viewModel.isScanning, isFalse);
      });
    });
  });
}
