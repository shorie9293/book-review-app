import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_restorer.dart';

/// [AutoBackupRestorer] の実装。
///
/// 手順: 読み出し → 復元可否判定 → **現状を強制保存** → 既存の復元経路で適用。
/// 現状保存を先に行うことで、復元に失敗しても直前の状態が1世代残る。
/// 例外は握り、[AutoBackupRestoreResult.ok] を false にして返す。
class AutoBackupRestorerImpl implements AutoBackupRestorer {
  /// 自動バックアップの保管先。
  final AutoBackupStore store;

  /// 現状の JSON を組み立てる（手動バックアップと同一経路を注入する）。
  final Future<String> Function() buildCurrentJson;

  /// 既存のバックアップ復元経路で JSON を適用する。
  final Future<void> Function(String json) applyBackup;

  /// 現在時刻（世代名の決定に使う）。
  final DateTime Function() _now;

  /// 自動バックアップの掟。
  final AutoBackupPolicy policy;

  /// 実装を生成する。
  AutoBackupRestorerImpl({
    required this.store,
    required this.buildCurrentJson,
    required this.applyBackup,
    AutoBackupPolicy policy = const AutoBackupPolicy(),
    DateTime Function()? now,
  })  : policy = policy,
        _now = now ?? DateTime.now;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    String? safetyFileName;
    try {
      final content = await store.read(fileName);
      if (!AutoBackupPresenter.canRestore(content)) {
        return AutoBackupRestoreResult(
          ok: false,
          message: 'このバックアップは復元できません',
          safetyFileName: safetyFileName,
        );
      }

      // 復元前の現状を必ず1世代残す（失敗しても巻き戻せる）。
      safetyFileName = AutoBackupPolicy.fileNameFor(_now());
      final currentJson = await buildCurrentJson();
      await store.write(safetyFileName, currentJson);

      await applyBackup(content!);
      return AutoBackupRestoreResult(
        ok: true,
        message: 'バックアップを復元しました',
        safetyFileName: safetyFileName,
      );
    } catch (_) {
      return AutoBackupRestoreResult(
        ok: false,
        message: '復元に失敗しました',
        safetyFileName: safetyFileName,
      );
    }
  }
}
