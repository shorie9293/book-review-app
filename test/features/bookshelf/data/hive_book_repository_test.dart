import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
    repository = HiveBookRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await Hive.deleteBoxFromDisk('books');
    tempDir.deleteSync(recursive: true);
  });

  group('HiveBookRepository', () {
    test('addBook - 書籍を追加してgetBooksで一覧を取得できる', () async {
      final book = Book(
        id: 'test-id-1',
        title: 'テスト駆動開発',
        author: 'Kent Beck',
        isbn: '978-4-274-21788-3',
        publisher: 'オーム社',
        publishedDate: '2020-01-15',
        pageCount: 300,
        description: 'TDDの古典的名著',
      );

      await repository.addBook(book);
      final books = await repository.getBooks();

      expect(books.length, 1);
      expect(books.first.id, 'test-id-1');
      expect(books.first.title, 'テスト駆動開発');
      expect(books.first.author, 'Kent Beck');
    });

    test('addBook - 複数の書籍を追加できる', () async {
      final book1 = Book(
        id: 'id-1',
        title: 'Title 1',
        author: 'Author 1',
        isbn: 'isbn-1',
      );
      final book2 = Book(
        id: 'id-2',
        title: 'Title 2',
        author: 'Author 2',
        isbn: 'isbn-2',
      );

      await repository.addBook(book1);
      await repository.addBook(book2);
      final books = await repository.getBooks();

      expect(books.length, 2);
    });

    test('getBookById - 存在するIDで書籍を取得できる', () async {
      final book = Book(
        id: 'find-me',
        title: 'Clean Code',
        author: 'Robert C. Martin',
        isbn: '978-0-1323-5088-4',
      );

      await repository.addBook(book);
      final found = await repository.getBookById('find-me');

      expect(found, isNotNull);
      expect(found!.title, 'Clean Code');
    });

    test('getBookById - 存在しないIDの場合はnullを返す', () async {
      final found = await repository.getBookById('non-existent');

      expect(found, isNull);
    });

    test('findByIsbn - ISBNで書籍を検索できる', () async {
      final book = Book(
        id: 'isbn-test',
        title: 'リファクタリング',
        author: 'Martin Fowler',
        isbn: '978-4-274-21788-3',
      );

      await repository.addBook(book);
      final found = await repository.findByIsbn('978-4-274-21788-3');

      expect(found, isNotNull);
      expect(found!.title, 'リファクタリング');
    });

    test('findByIsbn - 存在しないISBNの場合はnullを返す', () async {
      final found = await repository.findByIsbn('978-0-0000-0000-0');

      expect(found, isNull);
    });

    test('removeBook - 書籍を削除できる', () async {
      final book = Book(
        id: 'to-delete',
        title: 'Delete Me',
        author: 'Nobody',
        isbn: '000-0-0000-0000-0',
      );

      await repository.addBook(book);
      expect(await repository.getBooks(), hasLength(1));

      await repository.removeBook('to-delete');
      final books = await repository.getBooks();

      expect(books, isEmpty);
    });

    test('removeBook - 存在しないIDの削除はエラーにならない', () async {
      await repository.addBook(Book(
        id: 'keep-me',
        title: 'Keep Me',
        author: 'Someone',
        isbn: '111-1-1111-1111-1',
      ));

      await repository.removeBook('non-existent');
      expect(await repository.getBooks(), hasLength(1));
    });

    test('読書状態フィールドを保存・復元できる（round-trip）', () async {
      final finished = DateTime(2026, 6, 1);
      final book = Book(
        id: 'status-1',
        title: 'Clean Architecture',
        author: 'Robert C. Martin',
        isbn: '978-0-13-449416-6',
        pageCount: 432,
      ).copyWith(
        readingStatus: ReadingStatus.finished,
        currentPage: 432,
        finishedAt: finished,
      );

      await repository.addBook(book);
      final restored = await repository.getBookById('status-1');

      expect(restored, isNotNull);
      expect(restored!.readingStatus, ReadingStatus.finished);
      expect(restored.currentPage, 432);
      expect(restored.finishedAt, finished);
    });

    test('updateBook で読書状態を更新できる', () async {
      final book = Book(
        id: 'upd-1',
        title: '読書中にする本',
        author: 'A',
        isbn: 'u-1',
        pageCount: 200,
      );
      await repository.addBook(book);

      final reading =
          book.copyWith(readingStatus: ReadingStatus.reading, currentPage: 50);
      await repository.updateBook(reading);

      final restored = await repository.getBookById('upd-1');
      expect(restored!.readingStatus, ReadingStatus.reading);
      expect(restored.currentPage, 50);
    });

    test('updateBook は存在しない本には何もしない', () async {
      final book = Book(
        id: 'ghost',
        title: 'Ghost',
        author: 'A',
        isbn: 'g-1',
      ).copyWith(readingStatus: ReadingStatus.reading);

      await repository.updateBook(book);
      expect(await repository.getBookById('ghost'), isNull);
    });

    test('旧形式データ（読書状態キー無し）は積読として読める（後方互換）', () async {
      // 新しいフィールドを持たない旧JSONを直接書き込む
      final box = await Hive.openBox<String>('books');
      final oldJson = json.encode({
        'id': 'legacy-1',
        'title': '昔の本',
        'author': 'Old Author',
        'isbn': 'legacy-isbn',
      });
      await box.put('legacy-1', oldJson);

      final restored = await repository.getBookById('legacy-1');
      expect(restored, isNotNull);
      expect(restored!.readingStatus, ReadingStatus.unread);
      expect(restored.currentPage, 0);
      expect(restored.finishedAt, isNull);
    });
  });
}
