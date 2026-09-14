import 'package:book_review_app/domain/models/book_note.dart';

/// 読書メモ・引用リポジトリの抽象インターフェース。
///
/// 蔵書に紐づくメモの読み取り・追加・更新・削除を定義する。
/// 具象実装は Hive またはインメモリ（テスト用）に差し替え可能。
abstract class BookNoteRepository {
  /// 指定書籍のメモ一覧を取得する（ページ昇順→作成日時昇順）
  Future<List<BookNote>> getNotesByBookId(String bookId);

  /// 全書籍の全メモを取得する（作成日時昇順）
  Future<List<BookNote>> getAllNotes();

  /// メモを追加する
  Future<void> addNote(BookNote note);

  /// メモを更新する
  Future<void> updateNote(BookNote note);

  /// メモを削除する
  Future<void> deleteNote(String id);

  /// 指定書籍のメモをすべて削除する（蔵書の削除に追随）
  Future<void> deleteNotesByBookId(String bookId);
}
