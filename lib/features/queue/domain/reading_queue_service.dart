import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';

/// 「次に読む」キューの並び替え・解決を行う純粋ロジック。
///
/// UI・永続化に依存せず、与えられたリストのみから結果を返す。
/// すべてのメソッドは引数のリストを変更しない（非破壊）。
class ReadingQueueService {
  const ReadingQueueService._();

  /// position を 1..n に詰め直し、
  /// position 昇順 → addedAt 昇順 → bookId 昇順で安定ソートする。
  static List<ReadingQueueEntry> normalize(List<ReadingQueueEntry> entries) {
    final sorted = List<ReadingQueueEntry>.of(entries);
    sorted.sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      if (byPosition != 0) return byPosition;
      final byDate = a.addedAt.compareTo(b.addedAt);
      if (byDate != 0) return byDate;
      return a.bookId.compareTo(b.bookId);
    });
    return [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].position == i + 1
            ? sorted[i]
            : sorted[i].copyWith(position: i + 1),
    ];
  }

  /// [bookId] を末尾に追加する。
  ///
  /// 既に含まれるなら何も変更せず返す（冪等）。
  /// 空文字 [bookId] は [ArgumentError]。
  static List<ReadingQueueEntry> enqueue(
    List<ReadingQueueEntry> current,
    String bookId,
    DateTime addedAt,
  ) {
    if (bookId.isEmpty) {
      throw ArgumentError.value(bookId, 'bookId', 'bookId must not be empty');
    }
    final ordered = normalize(current);
    if (ordered.any((entry) => entry.bookId == bookId)) {
      return ordered;
    }
    return [
      ...ordered,
      ReadingQueueEntry(
        bookId: bookId,
        position: ordered.length + 1,
        addedAt: addedAt,
      ),
    ];
  }

  /// リスト順に position を 1..n へ振り直す（並び替え結果を確定させる）。
  ///
  /// [normalize] は position を第一キーに再ソートするため、
  /// 並び替え後のリストに [normalize] を再適用すると順序が打ち消される。
  /// 並び替え系は必ず本メソッドで確定させること。
  static List<ReadingQueueEntry> _renumber(List<ReadingQueueEntry> entries) {
    return [
      for (var i = 0; i < entries.length; i++)
        entries[i].position == i + 1
            ? entries[i]
            : entries[i].copyWith(position: i + 1),
    ];
  }

  /// [bookId] を除去して normalize する。
  static List<ReadingQueueEntry> dequeue(
    List<ReadingQueueEntry> current,
    String bookId,
  ) {
    return normalize(
      current.where((entry) => entry.bookId != bookId).toList(),
    );
  }

  /// [bookId] を1つ前へ移動する。先頭・不存在では何もしない。
  static List<ReadingQueueEntry> moveUp(
    List<ReadingQueueEntry> current,
    String bookId,
  ) {
    return _moveBy(current, bookId, -1);
  }

  /// [bookId] を1つ後ろへ移動する。末尾・不存在では何もしない。
  static List<ReadingQueueEntry> moveDown(
    List<ReadingQueueEntry> current,
    String bookId,
  ) {
    return _moveBy(current, bookId, 1);
  }

  /// [bookId] を 0 始まりの [index] へ移動する。範囲外では何もしない。
  static List<ReadingQueueEntry> moveTo(
    List<ReadingQueueEntry> current,
    String bookId,
    int index,
  ) {
    final normalized = normalize(current);
    final from = normalized.indexWhere((entry) => entry.bookId == bookId);
    if (from < 0 || index < 0 || index >= normalized.length || index == from) {
      return normalized;
    }
    final list = List<ReadingQueueEntry>.of(normalized);
    final moved = list.removeAt(from);
    list.insert(index, moved);
    return _renumber(list);
  }

  static List<ReadingQueueEntry> _moveBy(
    List<ReadingQueueEntry> current,
    String bookId,
    int delta,
  ) {
    final normalized = normalize(current);
    final from = normalized.indexWhere((entry) => entry.bookId == bookId);
    if (from < 0) return normalized;
    final to = from + delta;
    if (to < 0 || to >= normalized.length) return normalized;
    final list = List<ReadingQueueEntry>.of(normalized);
    final moved = list.removeAt(from);
    list.insert(to, moved);
    return _renumber(list);
  }

  /// キュー順を保ちつつ、[books] に存在しない bookId と
  /// readingStatus == finished の本を除外したリストを返す。
  static List<Book> resolveQueue(
    List<ReadingQueueEntry> entries,
    List<Book> books,
  ) {
    final byId = {for (final book in books) book.id: book};
    final result = <Book>[];
    for (final entry in normalize(entries)) {
      final book = byId[entry.bookId];
      if (book == null) continue;
      if (book.isFinished) continue;
      result.add(book);
    }
    return result;
  }

  /// 次に読むべき1冊（無ければ null）。
  static Book? nextToRead(
    List<ReadingQueueEntry> entries,
    List<Book> books,
  ) {
    final queue = resolveQueue(entries, books);
    return queue.isEmpty ? null : queue.first;
  }
}
