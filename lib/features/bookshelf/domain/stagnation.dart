import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/genre_service.dart';

/// 停滞理由の分類。
enum StagnationReason {
  /// 積読のまま一度も読書を開始していない。
  neverStarted,

  /// 読書中だが現在ページが 0 のまま進捗がない。
  noPageProgress,

  /// 読書中で進捗はあるが、追加から長期間経過している。
  longReading;

  /// 日本語ラベル。
  String get label {
    switch (this) {
      case StagnationReason.neverStarted:
        return '積読（未着手）';
      case StagnationReason.noPageProgress:
        return '読書中だが進捗なし';
      case StagnationReason.longReading:
        return '読書中（長期経過）';
    }
  }
}

/// 停滞している 1 冊分の判定結果。
class StagnationEntry {
  final Book book;
  final int daysStalled;
  final StagnationReason reason;

  StagnationEntry({
    required this.book,
    required this.daysStalled,
    required this.reason,
  }) {
    if (daysStalled < 0) {
      throw ArgumentError.value(daysStalled, 'daysStalled', '負の日数は許可しない');
    }
  }

  /// 一覧表示用の日数ラベル。
  String get daysLabel => '$daysStalled日経過';

  /// 進捗率ラベル（pageCount が不明なら null）。
  String? progressLabel() {
    final pageCount = book.pageCount;
    if (pageCount == null || pageCount <= 0) return null;
    final page = book.currentPage.clamp(0, pageCount);
    return '$page / $pageCount ページ';
  }
}

/// 積読・放置本の停滞判定を提供する純粋サービス。
class StagnationService {
  const StagnationService._();

  /// 既定の停滞判定閾値（日）。
  static const int defaultMinDays = 14;

  /// 選択可能な閾値チップ（日）。
  static const List<int> minDaysChoices = [7, 14, 30];

  /// [book] の追加日時からの経過日数。addedAt が未来なら 0。
  static int daysStalledFor(Book book, {required DateTime now}) {
    final addedAt = book.addedAt;
    if (addedAt == null) return 0;
    final days = now.difference(addedAt).inDays;
    return days < 0 ? 0 : days;
  }

  /// 読了以外で addedAt から [minDays] 以上経過した本を抽出する。
  ///
  /// addedAt が null の本は判定できないため対象外。入力順を保持する。
  static List<StagnationEntry> detect(
    List<Book> books, {
    required DateTime now,
    int minDays = defaultMinDays,
  }) {
    final entries = <StagnationEntry>[];
    for (final book in books) {
      if (book.readingStatus == ReadingStatus.finished) continue;
      if (book.addedAt == null) continue;
      final days = daysStalledFor(book, now: now);
      if (days < minDays) continue;
      entries.add(
        StagnationEntry(book: book, daysStalled: days, reason: reasonOf(book)),
      );
    }
    return entries;
  }

  /// 状態と進捗から停滞理由を分類する。
  static StagnationReason reasonOf(Book book) {
    if (book.readingStatus == ReadingStatus.reading) {
      return book.currentPage <= 0
          ? StagnationReason.noPageProgress
          : StagnationReason.longReading;
    }
    return StagnationReason.neverStarted;
  }

  /// 停滞日数の降順で並べ替える（非破壊）。同値は title 昇順 → id 昇順。
  static List<StagnationEntry> sortByDays(List<StagnationEntry> entries) {
    final sorted = List<StagnationEntry>.from(entries);
    sorted.sort((a, b) {
      final byDays = b.daysStalled.compareTo(a.daysStalled);
      if (byDays != 0) return byDays;
      final byTitle = a.book.title.compareTo(b.book.title);
      if (byTitle != 0) return byTitle;
      return a.book.id.compareTo(b.book.id);
    });
    return sorted;
  }

  /// [reason] で絞り込む。null は全件。
  static List<StagnationEntry> filterByReason(
    List<StagnationEntry> entries,
    StagnationReason? reason,
  ) {
    if (reason == null) return List<StagnationEntry>.from(entries);
    return entries.where((e) => e.reason == reason).toList();
  }

  /// 書名か著者の部分一致で絞り込む（正規化比較）。空クエリは全件。
  static List<StagnationEntry> searchByText(
    List<StagnationEntry> entries,
    String query,
  ) {
    final normalized = GenreService.normalize(query);
    if (normalized.isEmpty) return List<StagnationEntry>.from(entries);
    return entries
        .where((e) =>
            GenreService.normalize(e.book.title).contains(normalized) ||
            GenreService.normalize(e.book.author).contains(normalized))
        .toList();
  }

  /// 理由別の件数を数える。
  static Map<StagnationReason, int> countsByReason(List<StagnationEntry> entries) {
    final counts = <StagnationReason, int>{};
    for (final entry in entries) {
      counts[entry.reason] = (counts[entry.reason] ?? 0) + 1;
    }
    return counts;
  }
}