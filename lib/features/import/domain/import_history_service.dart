import 'package:book_review_app/features/import/domain/import_history_entry.dart';

/// 履歴全体の集計値。
class ImportHistorySummary {
  /// 実行回数
  final int runs;
  final int addedCount;
  final int skippedCount;
  final int notFoundCount;
  final int failedCount;

  const ImportHistorySummary({
    required this.runs,
    required this.addedCount,
    required this.skippedCount,
    required this.notFoundCount,
    required this.failedCount,
  });

  /// 4カウントの合計
  int get totalCount => addedCount + skippedCount + notFoundCount + failedCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportHistorySummary &&
          other.runs == runs &&
          other.addedCount == addedCount &&
          other.skippedCount == skippedCount &&
          other.notFoundCount == notFoundCount &&
          other.failedCount == failedCount;

  @override
  int get hashCode =>
      Object.hash(runs, addedCount, skippedCount, notFoundCount, failedCount);

  @override
  String toString() =>
      'ImportHistorySummary(runs: $runs, added: $addedCount, skipped: $skippedCount, '
      'notFound: $notFoundCount, failed: $failedCount)';
}

/// 取込履歴の並べ替え・絞り込み・集計を担う純粋ロジック。
///
/// I/O も現在時刻の取得も行わない（呼び出し側が値を注入する）。
class ImportHistoryService {
  const ImportHistoryService._();

  /// 保持する履歴の上限件数
  static const int maxEntries = 200;

  /// 全件表示を意味するモード値
  static const String allModesLabel = 'すべて';

  /// [entry] を先頭（最新）に追加した新しいリストを返す。
  ///
  /// - 入力リストは変更しない
  /// - 同一 [ImportHistoryEntry.id] が既にあれば置換する（重複追加しない）
  /// - [maxEntries] を超えた分は末尾（古い側）から切り捨てる
  static List<ImportHistoryEntry> append(
    List<ImportHistoryEntry> history,
    ImportHistoryEntry entry,
  ) {
    final result = <ImportHistoryEntry>[entry];
    for (final existing in history) {
      if (existing.id == entry.id) continue;
      result.add(existing);
    }
    if (result.length > maxEntries) {
      return result.sublist(0, maxEntries);
    }
    return result;
  }

  /// 実行日時の降順に並べ替えた新しいリストを返す（同時刻は id 昇順）。
  static List<ImportHistoryEntry> sortNewestFirst(
      List<ImportHistoryEntry> history) {
    final result = List<ImportHistoryEntry>.from(history);
    result.sort((a, b) {
      final byDate = b.importedAt.compareTo(a.importedAt);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return result;
  }

  /// [mode] に一致する履歴のみを返す。
  ///
  /// null・空文字・[allModesLabel]（'すべて'）は全件。
  static List<ImportHistoryEntry> filterByMode(
    List<ImportHistoryEntry> history,
    String? mode,
  ) {
    if (mode == null || mode.trim().isEmpty || mode == allModesLabel) {
      return List<ImportHistoryEntry>.from(history);
    }
    return history.where((e) => e.mode == mode).toList();
  }

  /// 履歴全体の合計を算出する。
  static ImportHistorySummary summarize(List<ImportHistoryEntry> history) {
    var added = 0;
    var skipped = 0;
    var notFound = 0;
    var failed = 0;
    for (final entry in history) {
      added += entry.addedCount;
      skipped += entry.skippedCount;
      notFound += entry.notFoundCount;
      failed += entry.failedCount;
    }
    return ImportHistorySummary(
      runs: history.length,
      addedCount: added,
      skippedCount: skipped,
      notFoundCount: notFound,
      failedCount: failed,
    );
  }

  /// 'yyyy/MM/dd HH:mm' 形式に整形する（intl 非依存）。
  static String formatTimestamp(DateTime timestamp) {
    final local = timestamp;
    return '${_pad(local.year, 4)}/${_pad(local.month, 2)}/${_pad(local.day, 2)}'
        ' ${_pad(local.hour, 2)}:${_pad(local.minute, 2)}';
  }

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}
