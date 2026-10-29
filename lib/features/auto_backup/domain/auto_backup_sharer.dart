/// 自動バックアップ1世代を外部へ共有する抽象。
abstract interface class AutoBackupSharer {
  /// [fileName] と [json] を共有する。
  Future<void> share(String fileName, String json);
}
