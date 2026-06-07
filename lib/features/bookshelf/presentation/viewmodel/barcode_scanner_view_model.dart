import 'package:flutter/foundation.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';

/// バーコードスキャン画面のビジネスロジックを管理する ViewModel。
///
/// スキャン状態・デバウンス・書籍検索・確認/キャンセルフローをカプセル化する。
class BarcodeScannerViewModel extends ChangeNotifier {
  bool _isScanning = false;
  String? lastScannedIsbn;
  DateTime? lastScanTime;
  Book? _scannedBook;
  Book? _confirmedBook;
  String? _errorMessage;
  String? _notFoundMessage;

  bool get isScanning => _isScanning;
  Book? get scannedBook => _scannedBook;
  Book? get confirmedBook => _confirmedBook;
  String? get errorMessage => _errorMessage;
  String? get notFoundMessage => _notFoundMessage;

  /// デバウンス期間（ミリ秒）
  static const int debounceMs = 2500;

  /// 同じISBNをデバウンス期間内に再検出したか
  bool isDuplicate(String isbn) {
    if (lastScannedIsbn != isbn) return false;
    if (lastScanTime == null) return false;
    final elapsed = DateTime.now().difference(lastScanTime!);
    return elapsed.inMilliseconds < debounceMs;
  }

  /// ISBNで書籍を検索する
  Future<void> searchBook(BookSearchService service, String isbn) async {
    _isScanning = true;
    _scannedBook = null;
    _confirmedBook = null;
    _errorMessage = null;
    _notFoundMessage = null;
    lastScannedIsbn = isbn;
    lastScanTime = DateTime.now();
    notifyListeners();

    try {
      final book = await service.searchByIsbn(isbn);
      if (book != null) {
        _scannedBook = book;
      } else {
        _notFoundMessage = '書籍が見つかりませんでした';
      }
    } catch (e) {
      _errorMessage = 'エラーが発生しました: $e';
    }
    _isScanning = false;
    notifyListeners();
  }

  /// スキャン結果を確認する
  Future<bool> confirmBook() async {
    _confirmedBook = _scannedBook;
    return true;
  }

  /// スキャンをキャンセルして再開する
  void cancelScan() {
    _scannedBook = null;
    _isScanning = false;
    notifyListeners();
  }

  /// スキャン可能状態に戻す
  void resumeScanning() {
    _isScanning = false;
    notifyListeners();
  }
}
