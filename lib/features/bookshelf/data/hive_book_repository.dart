import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'dart:convert';

/// Hive を使用した BookRepository の実装
class HiveBookRepository implements BookRepository {
  late Box<String> _box;

  /// 初期化（テスト時は明示的に呼び出す）
  Future<void> init({String? boxName}) async {
    _box = await Hive.openBox<String>(boxName ?? 'books');
  }

  /// テスト用：ボックスをクリアする
  Future<void> clear() async {
    await _box.clear();
  }

  /// ボックスを閉じる
  Future<void> close() async {
    await _box.close();
  }

  /// BookモデルをJSON文字列に変換
  String _bookToJson(Book book) {
    return json.encode({
      'id': book.id,
      'title': book.title,
      'author': book.author,
      'isbn': book.isbn,
      'coverImageUrl': book.coverImageUrl,
      'publisher': book.publisher,
      'publishedDate': book.publishedDate,
      'pageCount': book.pageCount,
      'description': book.description,
    });
  }

  /// JSON文字列からBookモデルに変換
  Book _bookFromJson(String jsonStr) {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      isbn: map['isbn'] as String,
      coverImageUrl: map['coverImageUrl'] as String?,
      publisher: map['publisher'] as String?,
      publishedDate: map['publishedDate'] as String?,
      pageCount: map['pageCount'] as int?,
      description: map['description'] as String?,
    );
  }

  @override
  Future<List<Book>> getBooks() async {
    return _box.values.map(_bookFromJson).toList();
  }

  @override
  Future<Book?> getBookById(String id) async {
    final jsonStr = _box.get(id);
    if (jsonStr == null) return null;
    return _bookFromJson(jsonStr);
  }

  @override
  Future<Book?> findByIsbn(String isbn) async {
    final normalizedIsbn = isbn.replaceAll('-', '');
    final books = await getBooks();
    for (final book in books) {
      if (book.isbn.replaceAll('-', '') == normalizedIsbn) {
        return book;
      }
    }
    return null;
  }

  @override
  Future<void> addBook(Book book) async {
    await _box.put(book.id, _bookToJson(book));
  }

  @override
  Future<void> removeBook(String id) async {
    await _box.delete(id);
  }
}
