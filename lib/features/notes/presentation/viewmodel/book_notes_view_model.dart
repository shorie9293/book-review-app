import 'package:flutter/foundation.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/domain/book_note_service.dart';

/// 読書メモ・引用画面のビジネスロジック。
///
/// 読み込み・絞り込み・追加・編集・削除の状態をカプセル化する。
class BookNotesViewModel extends ChangeNotifier {
  List<BookNote> _notes = [];
  bool _isLoading = true;
  String? _errorMessage;
  NoteKind? _kindFilter;
  String _keyword = '';
  String _bookId = '';

  /// 読み込み済みの全メモ（ソート済み）
  List<BookNote> get notes => List.unmodifiable(_notes);

  /// 種別・キーワードで絞り込んだ表示対象
  List<BookNote> get visibleNotes => BookNoteService.search(
        BookNoteService.filterByKind(_notes, _kindFilter),
        _keyword,
      );

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NoteKind? get kindFilter => _kindFilter;
  String get keyword => _keyword;
  String get bookId => _bookId;

  /// 読み込んだメモの種別件数
  Map<NoteKind, int> get countByKind => BookNoteService.countByKind(_notes);

  /// 読み込んだメモのページ範囲
  NotePageRange get pageRange => BookNoteService.pageRange(_notes);

  /// 読み込んだメモのタグ件数
  Map<String, int> get tagCounts => BookNoteService.tagCounts(_notes);

  /// 引用のみをページ順で返す
  List<BookNote> get quotes => BookNoteService.quotesOf(_notes, _bookId);

  /// 指定書籍のメモを読み込む
  Future<void> loadNotes(
      BookNoteRepository repository, String bookId) async {
    _bookId = bookId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notes = await repository.getNotesByBookId(bookId);
    } catch (e) {
      _errorMessage = e.toString();
      _notes = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  /// 種別フィルタを設定する（null で全件）
  void setKindFilter(NoteKind? kind) {
    if (_kindFilter == kind) return;
    _kindFilter = kind;
    notifyListeners();
  }

  /// 検索キーワードを設定する
  void setKeyword(String keyword) {
    if (_keyword == keyword) return;
    _keyword = keyword;
    notifyListeners();
  }

  /// メモを追加する
  Future<void> addNote(BookNoteRepository repository, BookNote note) async {
    await repository.addNote(note);
    await _reload(repository);
  }

  /// メモを更新する
  Future<void> updateNote(BookNoteRepository repository, BookNote note) async {
    await repository.updateNote(note);
    await _reload(repository);
  }

  /// メモを削除する
  Future<void> deleteNote(BookNoteRepository repository, String id) async {
    await repository.deleteNote(id);
    await _reload(repository);
  }

  Future<void> _reload(BookNoteRepository repository) async {
    _notes = await repository.getNotesByBookId(_bookId);
    notifyListeners();
  }
}
