/// 起動時自動バックアップの1世代分を表す。
class AutoBackupEntry {
  /// ファイル名（例: `auto_backup_20260105.json`）。
  final String fileName;

  /// 生成時刻（不明なら [AutoBackupStore] 側が FileStat.modified で補う）。
  final DateTime createdAt;

  /// 世代を生成する。
  const AutoBackupEntry({required this.fileName, required this.createdAt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoBackupEntry &&
          other.fileName == fileName &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(fileName, createdAt);

  @override
  String toString() => 'AutoBackupEntry($fileName, $createdAt)';
}

/// 自動バックアップの判定・命名・世代整理を担う純粋な掟。
///
/// IO も現在時刻の取得も持たない（[now] は呼び出し側が渡す）。
class AutoBackupPolicy {
  /// 既定の残す世代数。
  static const int defaultKeep = 3;

  /// 既定の実行間隔（1日1回）。
  static const Duration defaultInterval = Duration(hours: 24);

  /// 自動バックアップファイルの接頭辞。
  static const String filePrefix = 'auto_backup_';

  /// 自動バックアップファイルの接尾辞。
  static const String fileSuffix = '.json';

  /// 実行間隔。
  final Duration interval;

  /// 残す世代数（自動ファイルのみ数える）。
  final int keep;

  /// 掟を生成する。
  const AutoBackupPolicy({
    this.interval = defaultInterval,
    this.keep = defaultKeep,
  }) : assert(keep > 0, 'keep は1以上');

  /// 前回実行から [interval] 以上経過しているか。
  ///
  /// - 前回記録なし（[lastAt] が null）は実行する
  /// - ちょうど [interval] 経過も実行する
  /// - 未来時刻（端末時計の巻き戻り）は実行する
  bool shouldRun({DateTime? lastAt, required DateTime now}) {
    if (lastAt == null) return true;
    if (lastAt.isAfter(now)) return true;
    return now.difference(lastAt) >= interval;
  }

  /// ローカル暦の `auto_backup_yyyyMMdd.json` を組み立てる。
  static String fileNameFor(DateTime now) {
    final local = now.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$filePrefix$year$month$day$fileSuffix';
  }

  /// 自動バックアップの命名規約に一致するか（手動ファイルを巻き込まない）。
  static bool isAutoBackupFile(String fileName) {
    if (!fileName.startsWith(filePrefix)) return false;
    if (!fileName.endsWith(fileSuffix)) return false;
    final middle = fileName.substring(
      filePrefix.length,
      fileName.length - fileSuffix.length,
    );
    return RegExp(r'^\d{8}$').hasMatch(middle);
  }

  /// 自動ファイルのうち最新の生成時刻を返す（無ければ null）。
  ///
  /// 手動ファイルは判定材料にしない。
  DateTime? latestCreatedAt(List<AutoBackupEntry> entries) {
    DateTime? latest;
    for (final entry in entries) {
      if (!isAutoBackupFile(entry.fileName)) continue;
      if (latest == null || entry.createdAt.isAfter(latest)) {
        latest = entry.createdAt;
      }
    }
    return latest;
  }

  /// 削除すべき世代（[keep] を超えた古い自動ファイル）を返す。
  ///
  /// - 自動ファイルのみを対象にする（手動ファイルは決して返さない）
  /// - createdAt 降順、同時刻は fileName 降順で新しいとみなす
  /// - 新しい [keep] 件を残し、それ以外を削除対象として返す
  List<AutoBackupEntry> prune(List<AutoBackupEntry> entries) {
    final autos = entries
        .where((entry) => isAutoBackupFile(entry.fileName))
        .toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) return byTime;
        return b.fileName.compareTo(a.fileName);
      });
    if (autos.length <= keep) return const [];
    return autos.sublist(keep);
  }
}
