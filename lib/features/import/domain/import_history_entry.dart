import 'package:book_review_app/features/import/domain/bulk_import_service.dart';

/// 一括インポート1回分の履歴。
///
/// 実行結果（[BulkImportReport]）を後から振り返れるよう、
/// 件数の要約と代表 ISBN だけを保持する軽量な値オブジェクト。
class ImportHistoryEntry {
  /// 履歴の識別子（実行ごとに一意）
  final String id;

  /// 実行日時
  final DateTime importedAt;

  /// 取込モード（例: 'csv' / 'isbn'）
  final String mode;

  /// 新規追加件数
  final int addedCount;

  /// 登録済みで見送った件数
  final int skippedCount;

  /// 書誌が見つからなかった件数
  final int notFoundCount;

  /// 失敗件数
  final int failedCount;

  /// 代表 ISBN（先頭数件のみ・空リスト可）
  final List<String> sampleIsbns;

  ImportHistoryEntry({
    required this.id,
    required this.importedAt,
    required this.mode,
    required this.addedCount,
    required this.skippedCount,
    required this.notFoundCount,
    required this.failedCount,
    required this.sampleIsbns,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', '空の id は許容されない');
    }
    for (final count in [
      addedCount,
      skippedCount,
      notFoundCount,
      failedCount
    ]) {
      if (count < 0) {
        throw ArgumentError.value(count, 'count', '件数に負の値は許容されない');
      }
    }
  }

  /// 4カウントの合計（処理対象件数）
  int get totalCount => addedCount + skippedCount + notFoundCount + failedCount;

  /// 処理対象が1件も無かったか
  bool get isEmpty => totalCount == 0;

  /// 件数の要約（例: '追加3 / 登録済2 / 書誌なし1 / 失敗0'）
  String get summaryLabel => '${ImportOutcome.added.label}$addedCount'
      ' / ${ImportOutcome.skippedExisting.label}$skippedCount'
      ' / ${ImportOutcome.notFound.label}$notFoundCount'
      ' / ${ImportOutcome.failed.label}$failedCount';

  /// 実行の結末を表す短いラベル
  String get outcomeLabel {
    if (isEmpty) return '対象なし';
    if (failedCount > 0) return '一部失敗';
    return '完了';
  }

  /// 永続化用の Map へ変換する（日時は ISO8601 文字列）。
  Map<String, dynamic> toJson() => {
        'id': id,
        'importedAt': importedAt.toIso8601String(),
        'mode': mode,
        'addedCount': addedCount,
        'skippedCount': skippedCount,
        'notFoundCount': notFoundCount,
        'failedCount': failedCount,
        'sampleIsbns': List<String>.from(sampleIsbns),
      };

  /// Map から復元する。型不正・欠損・値の不正は [FormatException]。
  factory ImportHistoryEntry.fromJson(Map<String, dynamic> json) {
    final id = _requireString(json, 'id');
    final mode = _requireString(json, 'mode');
    final rawDate = _requireString(json, 'importedAt');

    final DateTime importedAt;
    try {
      importedAt = DateTime.parse(rawDate);
    } catch (e) {
      throw FormatException('importedAt が日時として解釈できない: $rawDate');
    }

    final added = _requireInt(json, 'addedCount');
    final skipped = _requireInt(json, 'skippedCount');
    final notFound = _requireInt(json, 'notFoundCount');
    final failed = _requireInt(json, 'failedCount');

    final rawSamples = json['sampleIsbns'];
    if (rawSamples is! List) {
      throw FormatException('sampleIsbns はリストでなければならない: $rawSamples');
    }
    final samples = <String>[];
    for (final s in rawSamples) {
      if (s is! String) {
        throw FormatException('sampleIsbns の要素は文字列である必要がある: $s');
      }
      samples.add(s);
    }

    try {
      return ImportHistoryEntry(
        id: id,
        importedAt: importedAt,
        mode: mode,
        addedCount: added,
        skippedCount: skipped,
        notFoundCount: notFound,
        failedCount: failed,
        sampleIsbns: samples,
      );
    } on ArgumentError catch (e) {
      throw FormatException('履歴の値が不正: ${e.message}');
    }
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('$key は文字列でなければならない: $value');
    }
    return value;
  }

  static int _requireInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw FormatException('$key は整数でなければならない: $value');
    }
    return value;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImportHistoryEntry &&
        other.id == id &&
        other.importedAt == importedAt &&
        other.mode == mode &&
        other.addedCount == addedCount &&
        other.skippedCount == skippedCount &&
        other.notFoundCount == notFoundCount &&
        other.failedCount == failedCount &&
        _listEquals(other.sampleIsbns, sampleIsbns);
  }

  @override
  int get hashCode => Object.hash(
        id,
        importedAt,
        mode,
        addedCount,
        skippedCount,
        notFoundCount,
        failedCount,
        Object.hashAll(sampleIsbns),
      );

  @override
  String toString() =>
      'ImportHistoryEntry($id, $mode, ${importedAt.toIso8601String()}, $summaryLabel)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// [BulkImportReport] から履歴エントリを組み立てる純粋関数。
///
/// [maxSamples] 件まで、報告に含まれる ISBN（空文字は除外）を先頭から採取する。
ImportHistoryEntry buildImportHistoryEntry({
  required BulkImportReport report,
  required String mode,
  required String id,
  required DateTime importedAt,
  int maxSamples = 5,
}) {
  final samples = <String>[];
  if (maxSamples > 0) {
    for (final record in report.records) {
      if (samples.length >= maxSamples) break;
      final isbn = record.entry.isbn;
      if (isbn.trim().isEmpty) continue;
      samples.add(isbn);
    }
  }

  return ImportHistoryEntry(
    id: id,
    importedAt: importedAt,
    mode: mode,
    addedCount: report.addedCount,
    skippedCount: report.skippedCount,
    notFoundCount: report.notFoundCount,
    failedCount: report.failedCount,
    sampleIsbns: List<String>.unmodifiable(samples),
  );
}
