import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';

final _validSummary = json.encode([
  {
    'summary': {
      'isbn': '9784774189079',
      'title': 'Test Driven Development',
      'publisher': 'Gijutsu-Hyoron',
      'pubdate': '2020-01-15',
      'cover': 'https://example.com/cover.jpg',
      'author': 'Kent Beck',
    }
  }
]);

void main() {
  group('BookSearchService', () {
    test('searchByIsbn - valid ISBN returns book info', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(),
            contains('https://api.openbd.jp/v1/get?isbn=9784774189079'));
        return http.Response(_validSummary, 200);
      });

      final service = BookSearchService(client: client);
      final book = await service.searchByIsbn('978-4-7741-8907-9');

      expect(book, isNotNull);
      expect(book!.title, 'Test Driven Development');
      expect(book.author, 'Kent Beck');
      expect(book.isbn, '978-4-7741-8907-9');
      expect(book.publisher, 'Gijutsu-Hyoron');
      expect(book.publishedDate, '2020-01-15');
      expect(book.coverImageUrl, 'https://example.com/cover.jpg');
    });

    test('searchByIsbn - null result returns null', () async {
      final client =
          MockClient((request) async => http.Response('[null]', 200));
      final service = BookSearchService(client: client);
      final book = await service.searchByIsbn('978-0-0000-0000-0');

      expect(book, isNull);
    });

    test('searchByIsbn - empty array returns null', () async {
      final client =
          MockClient((request) async => http.Response('[]', 200));
      final service = BookSearchService(client: client);
      final book = await service.searchByIsbn('978-0-0000-0000-0');

      expect(book, isNull);
    });

    test('searchByIsbn - network error throws Exception', () async {
      final client = MockClient(
          (request) async => http.Response('Internal Server Error', 500));
      final service = BookSearchService(client: client);

      expect(
        service.searchByIsbn('978-4-7741-8907-9'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
