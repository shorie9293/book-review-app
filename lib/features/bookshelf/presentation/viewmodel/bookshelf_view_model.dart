import 'package:flutter/foundation.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';

/// 本棚画面のビジネスロジックを管理する ViewModel。
///
/// 蔵書の読み込み・検索・追加・削除の状態と操作をカプセル化する。
/// [BookRepository] と [BookSearchService] を注入して使用する。
class BookshelfViewModel extends ChangeNotifier {
  List<Book> _books = [];
  Book? _foundBook;
  bool _isSearching = false;
  String? _errorMessage;
  bool _isLoading = true;

  List<Book> get books => List.unmodifiable(_books);
  Book? get foundBook => _foundBook;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  /// 蔵書一覧をリポジトリから読み込む
  Future<void> loadBooks(BookRepository repository) async {
    _isLoading = true;
    notifyListeners();

    final books = await repository.getBooks();
    _books = books;
    _isLoading = false;
    notifyListeners();
  }

  /// ISBN で書籍を検索する
  Future<void> searchByIsbn(BookSearchService service, String isbn) async {
    if (isbn.trim().isEmpty) return;

    _isSearching = true;
    _foundBook = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final book = await service.searchByIsbn(isbn);
      _foundBook = book;
      _isSearching = false;
      if (book == null) {
        _errorMessage = '書籍が見つかりませんでした';
      }
    } catch (e) {
      _isSearching = false;
      _errorMessage = '検索中にエラーが発生しました: $e';
    }
    notifyListeners();
  }

  /// 書籍を蔵書に追加する
  Future<void> addBook(BookRepository repository, Book book) async {
    await repository.addBook(book);
    _foundBook = null;
    await _reloadAfterMutation(repository);
  }

  /// 書籍を蔵書から削除する
  Future<void> deleteBook(BookRepository repository, String id) async {
    await repository.removeBook(id);
    await _reloadAfterMutation(repository);
  }

  Future<void> _reloadAfterMutation(BookRepository repository) async {
    _books = await repository.getBooks();
    notifyListeners();
  }
}
