import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/domain/book_note_service.dart';

/// Hive を使用した [BookNoteRepository] の実装。
///
/// メモは JSON 文字列として保存する（TypeAdapter 不要）。
/// 破損エントリは読み飛ばし、他のメモの読み取りを妨げない。
class HiveBookNoteRepository implements BookNoteRepository {
  late Box<String> _box;

  /// Hive のボックス名
  static const String defaultBoxName = 'book_notes';

  /// 初期化（テスト時は boxName を指定して呼び出す）
  Future<void> init({String? boxName}) async {
    _box = await Hive.openBox<String>(boxName ?? defaultBoxName);
  }

  /// テスト用：ボックスをクリアする
  Future<void> clear() async {
    await _box.clear();
  }

  /// ボックスを閉じる
  Future<void> close() async {
    await _box.close();
  }

  /// 破損エントリを読み飛ばして全件復元する
  List<BookNote> _readAll() {
    final notes = <BookNote>[];
    for (final raw in _box.values) {
      final note = _decode(raw);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  BookNote? _decode(String raw) {
    try {
      final map = json.decode(raw);
      if (map is! Map<String, dynamic>) return null;
      return BookNote.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async {
    return BookNoteService.notesOf(_readAll(), bookId);
  }

  @override
  Future<List<BookNote>> getAllNotes() async {
    return BookNoteService.sortNotes(_readAll());
  }

  @override
  Future<void> addNote(BookNote note) async {
    await _box.put(note.id, json.encode(note.toJson()));
  }

  @override
  Future<void> updateNote(BookNote note) async {
    await _box.put(note.id, json.encode(note.toJson()));
  }

  @override
  Future<void> deleteNote(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> deleteNotesByBookId(String bookId) async {
    final keys = _readAll()
        .where((note) => note.bookId == bookId)
        .map((note) => note.id)
        .toList();
    for (final key in keys) {
      await _box.delete(key);
    }
  }
}

/// テスト・プレビュー用のインメモリ実装。
class InMemoryBookNoteRepository implements BookNoteRepository {
  final Map<String, BookNote> _store = {};

  /// 現在保持しているメモ件数
  int get length => _store.length;

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async {
    return BookNoteService.notesOf(_store.values.toList(), bookId);
  }

  @override
  Future<List<BookNote>> getAllNotes() async {
    return BookNoteService.sortNotes(_store.values.toList());
  }

  @override
  Future<void> addNote(BookNote note) async {
    _store[note.id] = note;
  }

  @override
  Future<void> updateNote(BookNote note) async {
    _store[note.id] = note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> deleteNotesByBookId(String bookId) async {
    _store.removeWhere((_, note) => note.bookId == bookId);
  }
}
