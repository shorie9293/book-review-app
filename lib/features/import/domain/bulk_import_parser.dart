import 'isbn_validator.dart';

/// 一括インポートの入力行1件が取り込み可能かどうかの判定結果。
enum ImportEntryStatus {
  /// 取り込み可能（ISBN 妥当・入力内でも重複なし）
  valid,

  /// 入力内で ISBN が重複している
  duplicate,

  /// ISBN が不正（桁数・チェックディジット・使用不可文字）
  invalid;

  /// 画面表示用のラベル
  String get label => switch (this) {
        ImportEntryStatus.valid => '取込可',
        ImportEntryStatus.duplicate => '重複',
        ImportEntryStatus.invalid => 'ISBN不正',
      };
}

/// 一括インポートの解析結果1件分。
class ImportEntry {
  /// 元の入力文字列（前後の空白は除去済み）
  final String raw;

  /// 正規化後の ISBN（不正な場合も正規化を試みた結果を保持）
  final String isbn;

  /// CSV で指定された書名（未指定は null）
  final String? title;

  /// CSV で指定された著者名（未指定は null）
  final String? author;

  /// 入力上の行番号（1始まり）
  final int line;

  /// 判定結果
  final ImportEntryStatus status;

  const ImportEntry({
    required this.raw,
    required this.isbn,
    required this.line,
    required this.status,
    this.title,
    this.author,
  });

  /// 実際に取り込む対象か
  bool get isImportable => status == ImportEntryStatus.valid;

  @override
  String toString() => 'ImportEntry(line: $line, isbn: $isbn, status: ${status.name})';
}

/// 解析結果全体の集計。
class BulkImportParseResult {
  final List<ImportEntry> entries;

  const BulkImportParseResult(this.entries);

  /// 取り込み可能な件数
  int get validCount => entries.where((e) => e.status == ImportEntryStatus.valid).length;

  /// 入力内で重複していた件数
  int get duplicateCount => entries.where((e) => e.status == ImportEntryStatus.duplicate).length;

  /// ISBN が不正だった件数
  int get invalidCount => entries.where((e) => e.status == ImportEntryStatus.invalid).length;

  /// 入力が実質空か
  bool get isEmpty => entries.isEmpty;

  /// 取り込む対象が1件以上あるか
  bool get hasImportable => validCount > 0;

  /// 取り込み対象のみを返す
  List<ImportEntry> get importable =>
      entries.where((e) => e.status == ImportEntryStatus.valid).toList();
}

/// ISBN リスト・CSV テキストを [ImportEntry] の並びに解析する純粋ロジック。
///
/// - ISBN リスト: 1行に1冊（カンマ・タブ・セミコロン・空白区切りで複数可）
/// - CSV: 先頭行がヘッダなら `isbn` / `title` / `author` 列を名前で解決、
///   ヘッダが無ければ「ISBN, 書名, 著者」の並びとして解釈する
///
/// ISBN はハイフン・空白を許容して正規化し、入力内の重複は
/// [ImportEntryStatus.duplicate]（最初の出現のみ valid）とする。
class BulkImportParser {
  const BulkImportParser._();

  static final RegExp _listSeparators = RegExp(r'[,、;\t\u3000 ]+');

  /// ISBN リスト（1行1冊・複数区切り許容）を解析する。
  static BulkImportParseResult parseIsbnList(String text) {
    final entries = <ImportEntry>[];
    final seen = <String>{};
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final lineNumber = i + 1;
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      final tokens = trimmed.split(_listSeparators).where((t) => t.trim().isNotEmpty);
      for (final token in tokens) {
        entries.add(_buildEntry(
          raw: token.trim(),
          isbn: token.trim(),
          line: lineNumber,
          seen: seen,
        ));
      }
    }
    return BulkImportParseResult(entries);
  }

  /// CSV テキストを解析する。RFC4180 相当のダブルクォート囲みに対応。
  static BulkImportParseResult parseCsv(String text) {
    final entries = <ImportEntry>[];
    final seen = <String>{};
    final rows = _splitCsvRows(text);
    if (rows.isEmpty) return const BulkImportParseResult([]);

    var isbnColumn = 0;
    var titleColumn = 1;
    var authorColumn = 2;
    var startRow = 0;

    final header = rows.first;
    if (_looksLikeHeader(header)) {
      isbnColumn = _findColumn(header, const ['isbn', 'isbn13', 'isbnコード', 'isbnコード(isbn)', 'isbn番号']);
      if (isbnColumn < 0) isbnColumn = 0;
      titleColumn = _findColumn(header, const ['title', '書名', 'タイトル']);
      authorColumn = _findColumn(header, const ['author', '著者', '著者名']);
      startRow = 1;
    }

    for (var r = startRow; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      final lineNumber = r + 1;
      final rawIsbn = _cell(row, isbnColumn).trim();
      final title = _cell(row, titleColumn).trim();
      final author = _cell(row, authorColumn).trim();
      entries.add(_buildEntry(
        raw: row.join(','),
        isbn: rawIsbn,
        line: lineNumber,
        seen: seen,
        title: title.isEmpty ? null : title,
        author: author.isEmpty ? null : author,
      ));
    }
    return BulkImportParseResult(entries);
  }

  static ImportEntry _buildEntry({
    required String raw,
    required String isbn,
    required int line,
    required Set<String> seen,
    String? title,
    String? author,
  }) {
    final normalized = IsbnValidator.normalize(isbn);
    final ImportEntryStatus status;
    if (!IsbnValidator.isValid(isbn)) {
      status = ImportEntryStatus.invalid;
    } else if (seen.contains(normalized)) {
      status = ImportEntryStatus.duplicate;
    } else {
      seen.add(normalized);
      status = ImportEntryStatus.valid;
    }
    return ImportEntry(
      raw: raw,
      isbn: normalized.isEmpty ? isbn.trim() : normalized,
      line: line,
      status: status,
      title: title,
      author: author,
    );
  }

  static bool _looksLikeHeader(List<String> row) {
    return row.any((cell) {
      final v = cell.trim().toLowerCase();
      return v == 'isbn' || v.contains('isbn');
    });
  }

  static int _findColumn(List<String> header, List<String> candidates) {
    for (var i = 0; i < header.length; i++) {
      final v = header[i].trim().toLowerCase();
      if (candidates.contains(v)) return i;
    }
    return -1;
  }

  static String _cell(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index];
  }

  /// CSV を行→列に分解する（ダブルクォート囲み・エスケープ `""` 対応）。
  static List<List<String>> _splitCsvRows(String text) {
    final rows = <List<String>>[];
    var current = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    void endField() {
      current.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(current);
      current = <String>[];
    }

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (var i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < normalized.length && normalized[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          endField();
        } else if (ch == '\n') {
          endRow();
        } else {
          field.write(ch);
        }
      }
    }
    if (field.isNotEmpty || current.isNotEmpty) {
      endRow();
    }
    // 末尾の空行を除去
    while (rows.isNotEmpty && rows.last.every((c) => c.trim().isEmpty)) {
      rows.removeLast();
    }
    return rows;
  }
}
