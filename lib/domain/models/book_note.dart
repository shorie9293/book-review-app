/// 読書メモ・引用の種別
///
/// [memo] は読書中の気づき、[quote] は本文からの引用を表す。
enum NoteKind {
  memo('メモ'),
  quote('引用');

  const NoteKind(this.label);

  /// 画面表示用のラベル
  final String label;

  /// 文字列から復元する（未知・破損は [NoteKind.memo] へフォールバック）
  static NoteKind parse(String? value) {
    return NoteKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => NoteKind.memo,
    );
  }
}

/// 蔵書に紐づく読書メモ・引用のモデル。
///
/// ページ番号付きで記録でき、引用（quote）とメモ（memo）を区別する。
/// 同一性は `id` に基づく。
class BookNote {
  final String id;
  final String bookId;
  final NoteKind kind;
  final String content;

  /// ページ番号（未指定は null。指定時は 1 以上）
  final int? pageNumber;

  /// 付箋タグ（前後の空白は除去・空文字は除外）
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookNote({
    required this.id,
    required this.bookId,
    required this.content,
    this.kind = NoteKind.memo,
    this.pageNumber,
    List<String> tags = const [],
    required this.createdAt,
    DateTime? updatedAt,
  })  : assert(id != '', 'id must not be empty'),
        assert(bookId != '', 'bookId must not be empty'),
        assert(content.trim() != '', 'content must not be blank'),
        assert(pageNumber == null || pageNumber >= 1,
            'pageNumber must be >= 1 when specified'),
        tags = _normalizeTags(tags),
        updatedAt = updatedAt ?? createdAt;

  /// 空白除去・空文字除去・重複除去（出現順を保持）したタグ一覧
  static List<String> _normalizeTags(List<String> raw) {
    final result = <String>[];
    for (final tag in raw) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      if (!result.contains(trimmed)) result.add(trimmed);
    }
    return List.unmodifiable(result);
  }

  /// ページ番号の表示文字列（未指定は「ページ未指定」）
  String get pageLabel => pageNumber == null ? 'ページ未指定' : 'p.$pageNumber';

  /// 引用かどうか
  bool get isQuote => kind == NoteKind.quote;

  /// 本文の要約（[maxLength] 文字に丸める）
  String excerpt({int maxLength = 80}) {
    if (maxLength < 1) return '';
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}…';
  }

  BookNote copyWith({
    NoteKind? kind,
    String? content,
    int? pageNumber,
    bool clearPageNumber = false,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return BookNote(
      id: id,
      bookId: bookId,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      pageNumber: clearPageNumber ? null : (pageNumber ?? this.pageNumber),
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'kind': kind.name,
        'content': content,
        'pageNumber': pageNumber,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// JSON マップから復元する。
  ///
  /// 必須項目の欠落・型不一致・不変条件違反は [FormatException] を投げる
  /// （リポジトリ側で読み飛ばす判断ができるようにするため）。
  factory BookNote.fromJson(Map<String, dynamic> map) {
    final id = map['id'];
    final bookId = map['bookId'];
    final content = map['content'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('BookNote.id is missing');
    }
    if (bookId is! String || bookId.isEmpty) {
      throw const FormatException('BookNote.bookId is missing');
    }
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('BookNote.content is missing');
    }

    final rawPage = map['pageNumber'];
    final int? pageNumber;
    if (rawPage == null) {
      pageNumber = null;
    } else if (rawPage is int && rawPage >= 1) {
      pageNumber = rawPage;
    } else {
      throw const FormatException('BookNote.pageNumber is invalid');
    }

    final rawTags = map['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final tag in rawTags) {
        if (tag is String) tags.add(tag);
      }
    }

    final createdAt = DateTime.tryParse('${map['createdAt']}');
    if (createdAt == null) {
      throw const FormatException('BookNote.createdAt is invalid');
    }
    final updatedAt = DateTime.tryParse('${map['updatedAt']}') ?? createdAt;

    return BookNote(
      id: id,
      bookId: bookId,
      kind: NoteKind.parse(map['kind'] as String?),
      content: content,
      pageNumber: pageNumber,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookNote && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BookNote(id: $id, bookId: $bookId, kind: ${kind.name}, page: $pageNumber)';
}
