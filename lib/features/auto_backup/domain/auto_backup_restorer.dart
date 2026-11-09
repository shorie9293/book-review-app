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

/// 控えの設定（テーマ・文字サイズ等）も戻すか選べる復元器。
///
/// [AutoBackupRestorer] を継承した**別インターフェース**にしてある。
/// 既存の実装・フェイクは [AutoBackupRestorer] のままで動き続け、
/// 画面は「この型を実装している時だけ」設定の選択UIを出す。
abstract interface class AutoBackupRestorerWithOptions
    implements AutoBackupRestorer {
  /// [fileName] の世代を復元する。
  ///
  /// [includeSettings] が false なら控えの設定は適用せず、記録だけを戻す。
  Future<AutoBackupRestoreResult> restoreWithOptions(
    String fileName, {
    bool includeSettings = true,
  });
}
