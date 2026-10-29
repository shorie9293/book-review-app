import 'dart:convert';

import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';

/// 自動バックアップ1世代の表示用行。
///
/// 純粋な値オブジェクト（IO も現在時刻も持たない）。
class AutoBackupRow {
  /// 元の世代。
  final AutoBackupEntry entry;

  /// 内容の UTF-8 バイト長。
  final int byteSize;

  /// 新しい順の世代番号（1始まり）。
  final int generation;

  /// 復元可能な JSON か。
  final bool restorable;

  /// 表示用の日時（ローカル暦 `yyyy-MM-dd HH:mm`）。
  final String dateLabel;

  /// 表示用のサイズ（`512 B` / `12.4 KB` / `1.2 MB`）。
  final String sizeLabel;

  /// 一覧に出す1行の文言。
  final String displayLabel;

  /// 行を生成する。
  const AutoBackupRow({
    required this.entry,
    required this.byteSize,
    required this.generation,
    required this.restorable,
    required this.dateLabel,
    required this.sizeLabel,
    required this.displayLabel,
  });
}

/// 自動バックアップの閲覧表示を司る純粋な提示器。
class AutoBackupPresenter {
  /// 残す世代数（保持ラベルの算出に使う）。
  final int keep;

  /// 提示器を生成する。
  const AutoBackupPresenter({this.keep = AutoBackupPolicy.defaultKeep});

  /// ローカル暦の `yyyy-MM-dd HH:mm` を返す。
  static String formatDate(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  /// 1024基数・小数1桁のサイズ表記を返す。
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }

  /// 復元可能な JSON か（例外を投げない）。
  ///
  /// null・空文字・パース失敗・トップが Map でない場合は false。
  static bool canRestore(String? json) {
    if (json == null || json.isEmpty) return false;
    try {
      return jsonDecode(json) is Map;
    } catch (_) {
      return false;
    }
  }

  /// createdAt 降順 → fileName 降順で新しい順に並べ替える。
  static List<AutoBackupEntry> sortNewestFirst(List<AutoBackupEntry> entries) {
    final sorted = List<AutoBackupEntry>.of(entries);
    sorted.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      if (byTime != 0) return byTime;
      return b.fileName.compareTo(a.fileName);
    });
    return sorted;
  }

  /// 保持世代の要約（例: `保持 3世代中 2件`）。
  String retentionLabel(int count) => '保持 $keep世代中 $count件';

  /// 自動バックアップのみを新しい順に並べ、表示用の行を組み立てる。
  List<AutoBackupRow> buildRows({
    required List<AutoBackupEntry> entries,
    required Map<String, String?> contents,
  }) {
    final autos = sortNewestFirst(entries)
        .where((entry) => AutoBackupPolicy.isAutoBackupFile(entry.fileName))
        .toList();
    final rows = <AutoBackupRow>[];
    for (var i = 0; i < autos.length; i++) {
      final entry = autos[i];
      final content = contents[entry.fileName];
      final byteSize = content == null ? 0 : utf8.encode(content).length;
      final dateLabel = formatDate(entry.createdAt);
      final sizeLabel = formatSize(byteSize);
      rows.add(
        AutoBackupRow(
          entry: entry,
          byteSize: byteSize,
          generation: i + 1,
          restorable: canRestore(content),
          dateLabel: dateLabel,
          sizeLabel: sizeLabel,
          displayLabel: '$dateLabel / $sizeLabel / 第${i + 1}世代',
        ),
      );
    }
    return rows;
  }
}
