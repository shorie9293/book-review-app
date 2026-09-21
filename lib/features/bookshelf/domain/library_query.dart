import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';

/// 本棚の並び替え順
enum LibrarySortOrder {
  /// 書名昇順
  titleAsc,

  /// 追加日降順（既定・新しい順）
  addedAtDesc,

  /// 追加日昇順（古い順）
  addedAtAsc,

  /// ページ数降順（nullは末尾）
  pageCountDesc,

  /// ページ数昇順（nullは末尾）
  pageCountAsc,

  /// 読書状態順（unread → reading → finished）
  statusAsc;

  /// 画面表示用の日本語ラベル
  String get label => switch (this) {
        LibrarySortOrder.titleAsc => '書名（あ→ん）',
        LibrarySortOrder.addedAtDesc => '追加日（新しい順）',
        LibrarySortOrder.addedAtAsc => '追加日（古い順）',
        LibrarySortOrder.pageCountDesc => 'ページ数（多い順）',
        LibrarySortOrder.pageCountAsc => 'ページ数（少ない順）',
        LibrarySortOrder.statusAsc => '読書状態（積読→読了）',
      };
}

/// 本棚の検索・絞り込み・並び替え条件を表す不変クラス。
class LibraryQuery {
  /// 検索文字列（書名・著者を部分一致）
  final String text;

  /// 絞り込む読書状態（空なら全状態）
  final Set<ReadingStatus> statuses;

  /// 並び替え順
  final LibrarySortOrder sortOrder;

  const LibraryQuery({
    this.text = '',
    this.statuses = const {},
    this.sortOrder = LibrarySortOrder.addedAtDesc,
  });

  /// text / statuses / sortOrder を差し替えた新しいインスタンスを返す。
  LibraryQuery copyWith({
    String? text,
    Set<ReadingStatus>? statuses,
    LibrarySortOrder? sortOrder,
    bool clearText = false,
    bool clearStatuses = false,
  }) {
    return LibraryQuery(
      text: clearText ? '' : (text ?? this.text),
      statuses: clearStatuses ? const {} : (statuses ?? this.statuses),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// 何も条件を指定していない既定状態かどうか。
  bool get isDefault =>
      text.isEmpty &&
      statuses.isEmpty &&
      sortOrder == LibrarySortOrder.addedAtDesc;

  /// 有効な絞り込み条件の数（text / statuses / 非既定ソート）。
  int get activeFilterCount =>
      (text.trim().isEmpty ? 0 : 1) +
      statuses.length +
      (sortOrder == LibrarySortOrder.addedAtDesc ? 0 : 1);
}

/// [LibraryQuery] を本棚リストに適用する純粋関数群。
class LibraryQueryService {
  const LibraryQueryService._();

  /// 正規化: 全角英数字・全角スペース → 半角、小文字化、空白圧縮。
  static String normalize(String raw) {
    final sb = StringBuffer();
    for (final ch in raw.runes) {
      if (ch >= 0xFF01 && ch <= 0xFF5E) {
        // 全角ASCII → 半角ASCII
        sb.writeCharCode(ch - 0xFEE0);
      } else if (ch == 0x3000) {
        // 全角スペース → 半角スペース
        sb.writeCharCode(0x20);
      } else {
        sb.writeCharCode(ch);
      }
    }
    final halfWidth = sb.toString();
    final lower = halfWidth.toLowerCase();
    return lower.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// [books] を [query] に従って絞り込み・並び替えした新しいリストを返す。
  /// 入力リストは変更しない。同順の要素は元のindex昇順（安定ソート）。
  static List<Book> apply(List<Book> books, LibraryQuery query) {
    final indexed = List<(int, Book)>.generate(
      books.length,
      (i) => (i, books[i]),
      growable: false,
    );

    Iterable<(int, Book)> result = indexed;

    // テキスト絞り込み
    final text = normalize(query.text);
    if (text.isNotEmpty) {
      result = result.where((entry) {
        final (i, book) = entry;
        final title = normalize(book.title);
        final author = normalize(book.author);
        return title.contains(text) || author.contains(text);
      });
    }

    // 読書状態絞り込み
    final statuses = query.statuses;
    if (statuses.isNotEmpty) {
      result = result.where((entry) {
        final (i, book) = entry;
        return statuses.contains(book.readingStatus);
      });
    }

    final filtered = result.toList(growable: false);

    final sorted = [...filtered];
    sorted.sort((a, b) {
      final cmp = _compare(query.sortOrder, a.$2, b.$2);
      if (cmp != 0) return cmp;
      // 安定ソート: 同順は元index昇順
      return a.$1.compareTo(b.$1);
    });

    return sorted.map((e) => e.$2).toList(growable: false);
  }

  static int _compare(LibrarySortOrder order, Book a, Book b) {
    switch (order) {
      case LibrarySortOrder.titleAsc:
        return _compareNullableString(a.title, b.title);
      case LibrarySortOrder.addedAtDesc:
        return _compareNullableDateTime(b.addedAt, a.addedAt);
      case LibrarySortOrder.addedAtAsc:
        return _compareNullableDateTime(a.addedAt, b.addedAt);
      case LibrarySortOrder.pageCountDesc:
        return _compareNullableIntDesc(a.pageCount, b.pageCount);
      case LibrarySortOrder.pageCountAsc:
        return _compareNullableIntAsc(a.pageCount, b.pageCount);
      case LibrarySortOrder.statusAsc:
        return a.readingStatus.index.compareTo(b.readingStatus.index);
    }
  }

  /// nullは常に「最古」として扱い（昇順で先頭・降順で末尾）、
  /// null同士は元index順（安定ソートに委ねる）。
  static int _compareNullableDateTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  static int _compareNullableString(String? a, String? b) {
    if (a == null) return 0;
    if (b == null) return 0;
    return a.compareTo(b);
  }

  /// nullは末尾に置く。それ以外は数値比較。
  static int _compareNullableIntDesc(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1; // a(null)は末尾
    if (b == null) return -1;
    return b.compareTo(a);
  }

  static int _compareNullableIntAsc(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
