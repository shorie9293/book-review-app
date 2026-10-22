import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/genre_service.dart';
import 'package:book_review_app/features/duplicates/domain/duplicate_book_group.dart';

/// 統合計画(純粋データ)。
///
/// 実際の削除・保存は呼び出し側(リポジトリ/UI)が行う。
class DuplicateMergePlan {
  /// 統合後の代表蔵書（keep の id を保つ）。
  final Book merged;

  /// 削除される重複の id（組の順序を保つ）。
  final List<String> removedIds;

  const DuplicateMergePlan({required this.merged, required this.removedIds});

  /// 削除される冊数。
  int get removedCount => removedIds.length;

  @override
  String toString() =>
      'DuplicateMergePlan(mergedId: ${merged.id}, removed: $removedCount)';
}

/// 重複蔵書の検出・統合計画立案を担う純粋ドメインサービス。
///
/// 状態を持たず、実時計にも依存しない。入力は一切破壊しない。
class DuplicateBookService {
  const DuplicateBookService();

  /// ISBN正規化で除去する文字（全角/半角スペース・各種ハイフン類）。
  static final RegExp _isbnNoise =
      RegExp(r'[\s\u3000\-\u2010\u2011\u2012\u2013\u2014\u2015\u2212]');

  /// 全角/半角スペース・ハイフン各種('-','‐','–','—','−')を除去し
  /// trim + 大文字化する。結果が空なら '' を返す。
  static String normalizeIsbn(String raw) {
    final removed = raw.replaceAll(_isbnNoise, '');
    return removed.trim().toUpperCase();
  }

  /// 正規化ISBNが同一の蔵書を2冊以上の組として抽出する（純粋・入力非破壊）。
  ///
  /// - ISBN が正規化後に空の蔵書は無視する
  /// - 組内は addedAt 昇順(null は末尾) → 同時刻/null は id 昇順 → 元 index 昇順
  /// - 組の並びは count 降順 → isbnKey 昇順
  static List<DuplicateBookGroup> findGroups(List<Book> books) {
    final buckets = <String, List<_IndexedBook>>{};
    for (var i = 0; i < books.length; i++) {
      final key = normalizeIsbn(books[i].isbn);
      if (key.isEmpty) continue;
      buckets.putIfAbsent(key, () => <_IndexedBook>[]).add(
            _IndexedBook(index: i, book: books[i]),
          );
    }

    final groups = <DuplicateBookGroup>[];
    for (final entry in buckets.entries) {
      if (entry.value.length < 2) continue;
      final sorted = List<_IndexedBook>.of(entry.value)..sort(_compareEntries);
      groups.add(
        DuplicateBookGroup(
          isbnKey: entry.key,
          books: List<Book>.unmodifiable(sorted.map((e) => e.book)),
        ),
      );
    }

    groups.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.isbnKey.compareTo(b.isbnKey);
    });
    return groups;
  }

  /// 組内蔵書の比較（addedAt 昇順・null 末尾 → id 昇順 → 元 index 昇順）。
  ///
  /// Dart の [List.sort] は非安定なので index を明示タイブレークに使う。
  static int _compareEntries(_IndexedBook a, _IndexedBook b) {
    final aAt = a.book.addedAt;
    final bAt = b.book.addedAt;
    if (aAt != null && bAt != null) {
      final byAddedAt = aAt.compareTo(bAt);
      if (byAddedAt != 0) return byAddedAt;
    } else if (aAt != null) {
      return -1;
    } else if (bAt != null) {
      return 1;
    }
    final byId = a.book.id.compareTo(b.book.id);
    if (byId != 0) return byId;
    return a.index.compareTo(b.index);
  }

  /// [keepId] を代表として統合した結果を返す（純粋・[group] を変更しない）。
  ///
  /// [keepId] が組に無ければ [ArgumentError] を投げる。
  static DuplicateMergePlan planMerge(
    DuplicateBookGroup group,
    String keepId,
  ) {
    final books = group.books;
    final keepIndex = books.indexWhere((b) => b.id == keepId);
    if (keepIndex < 0) {
      throw ArgumentError.value(
        keepId,
        'keepId',
        '組に存在しない蔵書 id です',
      );
    }
    final keep = books[keepIndex];

    final merged = Book(
      id: keep.id,
      title: keep.title.isNotEmpty
          ? keep.title
          : _firstNonEmpty(books.map((b) => b.title)),
      author: keep.author.isNotEmpty
          ? keep.author
          : _firstNonEmpty(books.map((b) => b.author)),
      isbn: keep.isbn.isNotEmpty
          ? keep.isbn
          : _firstNonEmpty(books.map((b) => b.isbn)),
      coverImageUrl: keep.coverImageUrl ?? _firstNonNull(books.map((b) => b.coverImageUrl)),
      publisher: keep.publisher ?? _firstNonNull(books.map((b) => b.publisher)),
      publishedDate:
          keep.publishedDate ?? _firstNonNull(books.map((b) => b.publishedDate)),
      pageCount: keep.pageCount ?? _firstNonNull(books.map((b) => b.pageCount)),
      description: _longestDescription(books, keep),
      genres: _unionGenres(books),
      location: _nonEmpty(keep.location)
          ? keep.location
          : _firstNonEmptyOrNull(books.map((b) => b.location)),
      readingStatus: _topReadingStatus(books),
      currentPage: books.fold<int>(
        0,
        (max, b) => b.currentPage > max ? b.currentPage : max,
      ),
      finishedAt:
          keep.finishedAt ?? _firstNonNull(books.map((b) => b.finishedAt)),
      addedAt: _earliestAddedAt(books),
    );

    final removedIds = <String>[
      for (final book in books)
        if (book.id != keepId) book.id,
    ];

    return DuplicateMergePlan(merged: merged, removedIds: removedIds);
  }

  /// 例: '重複した蔵書が 2組（5冊）あります' / 空なら '重複した蔵書はありません'。
  static String summaryLabel(List<DuplicateBookGroup> groups) {
    if (groups.isEmpty) return '重複した蔵書はありません';
    final total = groups.fold<int>(0, (sum, g) => sum + g.count);
    return '重複した蔵書が ${groups.length}組（$total冊）あります';
  }

  // ---------------------------------------------------------------------------
  // 内部ヘルパー
  // ---------------------------------------------------------------------------

  /// 空でない最初の文字列。無ければ ''。
  static String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// null でない最初の値。
  static T? _firstNonNull<T>(Iterable<T?> values) {
    for (final value in values) {
      if (value != null) return value;
    }
    return null;
  }

  /// trim して空でない最初の文字列。無ければ null。
  static String? _firstNonEmptyOrNull(Iterable<String?> values) {
    for (final value in values) {
      if (_nonEmpty(value)) return value;
    }
    return null;
  }

  static bool _nonEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;

  /// 最も長い非空 description。同長なら [keep] を優先する。
  static String? _longestDescription(List<Book> books, Book keep) {
    final keepDescription = keep.description;
    var best = _nonEmpty(keepDescription) ? keepDescription : null;
    var bestLength = best?.length ?? -1;
    for (final book in books) {
      if (identical(book, keep)) continue;
      final description = book.description;
      if (!_nonEmpty(description)) continue;
      if (description!.length > bestLength) {
        best = description;
        bestLength = description.length;
      }
    }
    return best;
  }

  /// 全冊のジャンルを正規化した和集合（空除外・大小無視・初出順）。
  static List<String> _unionGenres(List<Book> books) {
    final result = <String>[];
    final seen = <String>{};
    for (final book in books) {
      for (final raw in book.genres) {
        final normalized = GenreService.normalize(raw);
        if (normalized.isEmpty) continue;
        if (seen.add(normalized)) result.add(normalized);
      }
    }
    return result;
  }

  /// finished > reading > unread の優先順で最上位の状態。
  static ReadingStatus _topReadingStatus(List<Book> books) {
    var top = ReadingStatus.unread;
    for (final book in books) {
      if (_statusRank(book.readingStatus) > _statusRank(top)) {
        top = book.readingStatus;
      }
    }
    return top;
  }

  static int _statusRank(ReadingStatus status) => switch (status) {
        ReadingStatus.unread => 0,
        ReadingStatus.reading => 1,
        ReadingStatus.finished => 2,
      };

  /// 組内で最も早い非nullの addedAt。全てnullならnull。
  static DateTime? _earliestAddedAt(List<Book> books) {
    DateTime? earliest;
    for (final book in books) {
      final addedAt = book.addedAt;
      if (addedAt == null) continue;
      if (earliest == null || addedAt.isBefore(earliest)) {
        earliest = addedAt;
      }
    }
    return earliest;
  }
}

/// 元 index を保持した蔵書（安定ソート用）。
class _IndexedBook {
  final int index;
  final Book book;

  const _IndexedBook({required this.index, required this.book});
}
