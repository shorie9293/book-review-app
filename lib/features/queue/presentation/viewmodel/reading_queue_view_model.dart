import 'package:flutter/foundation.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/domain/repositories/reading_queue_repository.dart';
import 'package:book_review_app/features/queue/domain/reading_queue_service.dart';

/// 「次に読む」キュー画面のビジネスロジック。
///
/// キューの読み込み・追加・削除・並び替えと、
/// 書籍一覧との解決（[queue] / [nextToRead]）をカプセル化する。
class ReadingQueueViewModel extends ChangeNotifier {
  List<ReadingQueueEntry> _entries = [];
  List<Book> _books;
  bool _isLoading = true;
  String? _errorMessage;

  /// 書籍一覧の解決に使う関数（テストで差し替え可能）
  final Future<List<Book>> Function()? booksLoader;

  ReadingQueueViewModel({this.booksLoader, List<Book>? initialBooks})
      : _books = initialBooks ?? const [];

  /// キューの生エントリ（normalize 済み）
  List<ReadingQueueEntry> get entries => List.unmodifiable(_entries);

  /// 書籍に解決済みのキュー（読了・不在の本を除外）
  List<Book> get queue => ReadingQueueService.resolveQueue(_entries, _books);

  /// 次に読むべき1冊（無ければ null）
  Book? get nextToRead => ReadingQueueService.nextToRead(_entries, _books);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 解決前の書籍一覧（読み込み済み）
  List<Book> get books => List.unmodifiable(_books);

  /// キューへ追加可能な積読（読了済み・既にキューの本を除く）。
  ///
  /// 書籍一覧の並び順を保つ（非破壊）。
  List<Book> get candidates {
    final queued = _entries.map((entry) => entry.bookId).toSet();
    return [
      for (final book in _books)
        if (!book.isFinished && !queued.contains(book.id)) book,
    ];
  }

  /// キューと書籍一覧を読み込む。
  Future<void> load(
    ReadingQueueRepository repository, {
    List<Book>? books,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _entries = await repository.loadEntries();
      if (books != null) {
        _books = books;
      } else if (booksLoader != null) {
        _books = await booksLoader!();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _entries = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> add(
    ReadingQueueRepository repository,
    String bookId, {
    DateTime? addedAt,
  }) async {
    _entries = ReadingQueueService.enqueue(
      _entries,
      bookId,
      addedAt ?? DateTime.now(),
    );
    await repository.saveEntries(_entries);
    notifyListeners();
  }

  Future<void> remove(
    ReadingQueueRepository repository,
    String bookId,
  ) async {
    _entries = ReadingQueueService.dequeue(_entries, bookId);
    await repository.saveEntries(_entries);
    notifyListeners();
  }

  Future<void> moveUp(
    ReadingQueueRepository repository,
    String bookId,
  ) async {
    _entries = ReadingQueueService.moveUp(_entries, bookId);
    await repository.saveEntries(_entries);
    notifyListeners();
  }

  Future<void> moveDown(
    ReadingQueueRepository repository,
    String bookId,
  ) async {
    _entries = ReadingQueueService.moveDown(_entries, bookId);
    await repository.saveEntries(_entries);
    notifyListeners();
  }
}
