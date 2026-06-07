import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';

void main() {
  group('Book', () {
    test('should create with required fields', () {
      final book = Book(
        id: '123',
        title: 'テスト駆動開発',
        author: 'Kent Beck',
        isbn: '978-4-274-21788-3',
      );

      expect(book.id, '123');
      expect(book.title, 'テスト駆動開発');
      expect(book.author, 'Kent Beck');
      expect(book.isbn, '978-4-274-21788-3');
    });

    test('should have nullable optional fields as null by default', () {
      final book = Book(
        id: '123',
        title: 'テスト駆動開発',
        author: 'Kent Beck',
        isbn: '978-4-274-21788-3',
      );

      expect(book.coverImageUrl, isNull);
      expect(book.publisher, isNull);
      expect(book.publishedDate, isNull);
      expect(book.pageCount, isNull);
      expect(book.description, isNull);
    });

    test('should accept all optional fields', () {
      final book = Book(
        id: '456',
        title: 'Clean Code',
        author: 'Robert C. Martin',
        isbn: '978-0-13-235088-4',
        coverImageUrl: 'https://example.com/cover.jpg',
        publisher: 'Prentice Hall',
        publishedDate: '2008-08-01',
        pageCount: 464,
        description: 'A Handbook of Agile Software Craftsmanship',
      );

      expect(book.coverImageUrl, 'https://example.com/cover.jpg');
      expect(book.publisher, 'Prentice Hall');
      expect(book.publishedDate, '2008-08-01');
      expect(book.pageCount, 464);
      expect(book.description, 'A Handbook of Agile Software Craftsmanship');
    });

    test('== should compare by id', () {
      final book1 = Book(
        id: '123',
        title: 'Title A',
        author: 'Author A',
        isbn: 'isbn-a',
      );
      final book2 = Book(
        id: '123',
        title: 'Title B',
        author: 'Author B',
        isbn: 'isbn-b',
      );
      final book3 = Book(
        id: '456',
        title: 'Title A',
        author: 'Author A',
        isbn: 'isbn-a',
      );

      expect(book1, equals(book2)); // same id
      expect(book1, isNot(equals(book3))); // different id
    });

    test('hashCode should be based on id', () {
      final book1 = Book(
        id: '123',
        title: 'Title A',
        author: 'Author A',
        isbn: 'isbn-a',
      );
      final book2 = Book(
        id: '123',
        title: 'Title B',
        author: 'Author B',
        isbn: 'isbn-b',
      );

      expect(book1.hashCode, equals(book2.hashCode));
    });

    test('toString should include id and title', () {
      final book = Book(
        id: '123',
        title: 'テスト駆動開発',
        author: 'Kent Beck',
        isbn: '978-4-274-21788-3',
      );

      expect(book.toString(), contains('123'));
      expect(book.toString(), contains('テスト駆動開発'));
    });
  });
}
