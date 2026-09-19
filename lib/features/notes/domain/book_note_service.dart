import 'package:book_review_app/domain/models/book_note.dart';

/// ページ番号の範囲（最小・最大）。ページ未指定のみの場合は両方 null。
class NotePageRange {
  final int? min;
  final int? max;

  const NotePageRange({this.min, this.max});

  /// 範囲に有効なページが存在するか
  bool get isEmpty => min == null || max == null;

  /// ページ指定のあるメモの件数からなる幅（1件なら 0）
  int get span => isEmpty ? 0 : (max! - min!);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotePageRange &&
          runtimeType == other.runtimeType &&
          min == other.min &&
          max == other.max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'NotePageRange(min: $min, max: $max)';
}

/// 読書メモ・引用の集計・絞り込みを行う純粋ロジック。
///
/// UI・永続化に依存せず、与えられたリストのみから結果を返す。
class BookNoteService {
  const BookNoteService._();

  /// ページ昇順（未指定は末尾）→ 作成日時昇順 → ID 昇順で安定ソートする
  static List<BookNote> sortNotes(List<BookNote> notes) {
    final sorted = List<BookNote>.of(notes);
    sorted.sort((a, b) {
      final pa = a.pageNumber;
      final pb = b.pageNumber;
      if (pa != pb) {
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pa.compareTo(pb);
      }
      final byDate = a.createdAt.compareTo(b.createdAt);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// 指定書籍のメモをソートして返す
  static List<BookNote> notesOf(List<BookNote> notes, String bookId) {
    return sortNotes(notes.where((note) => note.bookId == bookId).toList());
  }

  /// 種別ごとの件数（出現しない種別も 0 件として含む）
  static Map<NoteKind, int> countByKind(List<BookNote> notes) {
    final counts = {for (final kind in NoteKind.values) kind: 0};
    for (final note in notes) {
      counts[note.kind] = (counts[note.kind] ?? 0) + 1;
    }
    return counts;
  }

  /// ページ指定のあるメモの範囲。1件もなければ [NotePageRange.isEmpty] が真
  static NotePageRange pageRange(List<BookNote> notes) {
    int? min;
    int? max;
    for (final note in notes) {
      final page = note.pageNumber;
      if (page == null) continue;
      if (min == null || page < min) min = page;
      if (max == null || page > max) max = page;
    }
    return NotePageRange(min: min, max: max);
  }

  /// タグごとの件数。件数降順 → タグ名昇順。
  static Map<String, int> tagCounts(List<BookNote> notes) {
    final counts = <String, int>{};
    for (final note in notes) {
      for (final tag in note.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return {for (final entry in entries) entry.key: entry.value};
  }

  /// 書籍IDごとに分類する（各リストはソート済み）
  static Map<String, List<BookNote>> groupByBook(List<BookNote> notes) {
    final grouped = <String, List<BookNote>>{};
    for (final note in notes) {
      grouped.putIfAbsent(note.bookId, () => []).add(note);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: sortNotes(entry.value),
    };
  }

  /// 種別で絞り込む（[kind] が null なら全件。順序は保持）
  static List<BookNote> filterByKind(List<BookNote> notes, NoteKind? kind) {
    if (kind == null) return List<BookNote>.of(notes);
    return notes.where((note) => note.kind == kind).toList();
  }

  /// タグで絞り込む（順序は保持）
  static List<BookNote> filterByTag(List<BookNote> notes, String tag) {
    final target = tag.trim();
    if (target.isEmpty) return List<BookNote>.of(notes);
    return notes.where((note) => note.tags.contains(target)).toList();
  }

  /// 本文またはタグにキーワードを含むメモを返す（大文字小文字を無視）
  static List<BookNote> search(List<BookNote> notes, String keyword) {
    final needle = keyword.trim().toLowerCase();
    if (needle.isEmpty) return List<BookNote>.of(notes);
    return notes.where((note) {
      if (note.content.toLowerCase().contains(needle)) return true;
      return note.tags
          .any((tag) => tag.toLowerCase().contains(needle));
    }).toList();
  }

  /// 指定書籍の引用だけをページ順で返す
  static List<BookNote> quotesOf(List<BookNote> notes, String bookId) {
    return sortNotes(
      notes
          .where((note) => note.bookId == bookId && note.isQuote)
          .toList(),
    );
  }

  /// お気に入りのメモだけを返す。
  ///
  /// bookId 昇順 → ページ番号昇順（未指定は末尾）→ 作成日時昇順 → id 昇順で
  /// 安定ソートする。入力リストは変更しない。
  static List<BookNote> favoritesOf(List<BookNote> notes) {
    final favorites = notes.where((note) => note.isFavorite).toList();
    favorites.sort((a, b) {
      final byBook = a.bookId.compareTo(b.bookId);
      if (byBook != 0) return byBook;
      final pa = a.pageNumber;
      final pb = b.pageNumber;
      if (pa != pb) {
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pa.compareTo(pb);
      }
      final byDate = a.createdAt.compareTo(b.createdAt);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return favorites;
  }

  /// お気に入りを書籍IDごとに分類する（各リストは [sortNotes] 順、キーは昇順）
  static Map<String, List<BookNote>> favoritesByBook(
      List<BookNote> notes) {
    final grouped = <String, List<BookNote>>{};
    for (final note in favoritesOf(notes)) {
      grouped.putIfAbsent(note.bookId, () => []).add(note);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: sortNotes(entry.value),
    };
  }

  /// お気に入りの件数
  static int favoriteCount(List<BookNote> notes) =>
      notes.where((note) => note.isFavorite).length;
}
