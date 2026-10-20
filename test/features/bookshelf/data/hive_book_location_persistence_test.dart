import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  const boxName = 'books_locations';
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_location_test_');
    Hive.init(tempDir.path);
    repository = HiveBookRepository();
    await repository.init(boxName: boxName);
  });

  tearDown(() async {
    await repository.clear();
    await repository.close();
    await Hive.deleteBoxFromDisk(boxName);
    tempDir.deleteSync(recursive: true);
  });

  group('HiveBookRepository location 永続化', () {
    test('location付きBookをsave→getBooks/getBookByIdで復元できる（往復）', () async {
      final book = Book(
        id: 'loc-1',
        title: '所在つきの本',
        author: '著者',
        isbn: 'loc-isbn-1',
        location: '本棚 一段目',
      );

      await repository.addBook(book);

      final byId = await repository.getBookById('loc-1');
      expect(byId, isNotNull);
      expect(byId!.location, '本棚 一段目');

      final books = await repository.getBooks();
      expect(books, hasLength(1));
      expect(books.first.location, '本棚 一段目');
    });

    test('location未設定のBookはnullで往復する', () async {
      await repository.addBook(Book(
        id: 'loc-2',
        title: '所在なしの本',
        author: '著者',
        isbn: 'loc-isbn-2',
      ));

      final restored = await repository.getBookById('loc-2');
      expect(restored, isNotNull);
      expect(restored!.location, isNull);
    });

    test('updateBookでlocationを変更・解除できる', () async {
      await repository.addBook(Book(
        id: 'loc-3',
        title: '更新対象',
        author: '著者',
        isbn: 'loc-isbn-3',
        location: '本棚',
      ));

      await repository.updateBook(Book(
        id: 'loc-3',
        title: '更新対象',
        author: '著者',
        isbn: 'loc-isbn-3',
        location: '書斎',
      ));
      expect((await repository.getBookById('loc-3'))!.location, '書斎');

      await repository.updateBook(Book(
        id: 'loc-3',
        title: '更新対象',
        author: '著者',
        isbn: 'loc-isbn-3',
      ));
      expect((await repository.getBookById('loc-3'))!.location, isNull);
    });

    test('旧形式JSON（locationキー無し）からはnullで復元される（後方互換）', () async {
      final box = await Hive.openBox<String>(boxName);
      final oldJson = json.encode({
        'id': 'legacy-loc-1',
        'title': '昔の本',
        'author': 'Old Author',
        'isbn': 'legacy-isbn-loc',
      });
      await box.put('legacy-loc-1', oldJson);

      final restored = await repository.getBookById('legacy-loc-1');
      expect(restored, isNotNull);
      expect(restored!.title, '昔の本');
      expect(restored.location, isNull);

      final books = await repository.getBooks();
      expect(books, hasLength(1));
      expect(books.first.location, isNull);
    });
  });
}
