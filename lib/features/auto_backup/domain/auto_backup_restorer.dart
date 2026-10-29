/// 自動バックアップ復元の結果。
class AutoBackupRestoreResult {
  /// 復元に成功したか。
  final bool ok;

  /// 利用者向けの文言。
  final String message;

  /// 復元前に現状を退避したファイル名（失敗時は null もあり得る）。
  final String? safetyFileName;

  /// 結果を生成する。
  const AutoBackupRestoreResult({
    required this.ok,
    required this.message,
    this.safetyFileName,
  });
}

/// 自動バックアップ1世代を現状データへ適用する抽象。
abstract interface class AutoBackupRestorer {
  /// [fileName] の世代を復元する（例外は投げず結果に畳む）。
  Future<AutoBackupRestoreResult> restore(String fileName);
}
