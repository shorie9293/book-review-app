import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_genre_test_');
    Hive.init(tempDir.path);
    repository = HiveBookRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await Hive.deleteBoxFromDisk('books');
    tempDir.deleteSync(recursive: true);
  });

  group('HiveBookRepository genres 永続化', () {
    test('genres付きBookをsave→getBooks/getBookByIdで完全に復元できる（往復）', () async {
      final book = Book(
        id: 'genre-1',
        title: '技術書の本',
        author: '著者',
        isbn: 'isbn-1',
        genres: ['技術書', ' 小説 ', 'ビジネス書'],
      );

      await repository.addBook(book);

      final byId = await repository.getBookById('genre-1');
      expect(byId, isNotNull);
      expect(byId!.genres, ['技術書', ' 小説 ', 'ビジネス書']);

      final books = await repository.getBooks();
      expect(books, hasLength(1));
      expect(books.first.genres, ['技術書', ' 小説 ', 'ビジネス書']);
    });

    test('旧形式JSON（genresキー無し）からはgenresが空リストで復元される（後方互換）', () async {
      // genres キーを持たない旧JSONを直接書き込む
      final box = await Hive.openBox<String>('books');
      final oldJson = json.encode({
        'id': 'legacy-genre-1',
        'title': '昔の本',
        'author': 'Old Author',
        'isbn': 'legacy-isbn',
      });
      await box.put('legacy-genre-1', oldJson);

      final restored = await repository.getBookById('legacy-genre-1');
      expect(restored, isNotNull);
      expect(restored!.title, '昔の本');
      expect(restored.genres, isEmpty);
    });
  });
}
