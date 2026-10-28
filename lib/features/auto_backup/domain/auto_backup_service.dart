import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';

/// 自動バックアップ1回分の結果。
class AutoBackupResult {
  /// 実際に書き出したか。
  final bool ran;

  /// 書き出したファイル名（スキップ・失敗時は null）。
  final String? fileName;

  /// 世代整理で削除した件数。
  final int pruned;

  /// 失敗理由（成功・スキップ時は null）。
  final Object? error;

  /// 結果を生成する。
  const AutoBackupResult({
    required this.ran,
    this.fileName,
    this.pruned = 0,
    this.error,
  });

  /// スキップ（間隔未経過）の結果。
  const AutoBackupResult.skipped()
      : ran = false,
        fileName = null,
        pruned = 0,
        error = null;

  /// 失敗の結果。
  const AutoBackupResult.failed(this.error)
      : ran = false,
        fileName = null,
        pruned = 0;

  /// 例外なく完了したか。
  bool get isOk => error == null;
}

/// 起動時1日1回の自動バックアップを司る。
///
/// 手順: 一覧 → 最新 → 実行判定 → JSON生成 → 書き出し → 一覧 → 世代整理 → 削除。
/// 例外は全て握り、起動を妨げない。
class AutoBackupService {
  /// 保管先。
  final AutoBackupStore store;

  /// 実行判定・命名・世代整理の掟。
  final AutoBackupPolicy policy;

  final DateTime Function() _now;

  /// [now] を注入できる（既定は [DateTime.now]）。
  AutoBackupService({
    required this.store,
    this.policy = const AutoBackupPolicy(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// 1回分を実行する（24時間未満・同日はスキップし冪等）。
  Future<AutoBackupResult> run(Future<String> Function() buildJson) async {
    try {
      final now = _now();
      final before = await store.list();
      final latest = policy.latestCreatedAt(before);
      if (!policy.shouldRun(lastAt: latest, now: now)) {
        return const AutoBackupResult.skipped();
      }

      final fileName = AutoBackupPolicy.fileNameFor(now);
      final json = await buildJson();
      await store.write(fileName, json);

      final after = await store.list();
      var pruned = 0;
      for (final entry in policy.prune(after)) {
        await store.delete(entry.fileName);
        pruned++;
      }
      return AutoBackupResult(ran: true, fileName: fileName, pruned: pruned);
    } catch (error) {
      return AutoBackupResult.failed(error);
    }
  }
}
