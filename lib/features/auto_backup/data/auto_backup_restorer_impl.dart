import 'dart:async';

import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_restorer.dart';

/// [AutoBackupRestorer] の実装。
///
/// 手順: 読み出し → 復元可否判定 → **現状を強制保存** → 既存の復元経路で適用。
/// 現状保存を先に行うことで、復元に失敗しても直前の状態が1世代残る。
/// 例外は握り、[AutoBackupRestoreResult.ok] を false にして返す。
///
/// 控えに設定（テーマ・文字サイズ等）が載っている世代では、
/// [restoreWithOptions] の `includeSettings` で設定の適用可否を選べる。
class AutoBackupRestorerImpl implements AutoBackupRestorerWithOptions {
  /// 自動バックアップの保管先。
  final AutoBackupStore store;

  /// 現状の JSON を組み立てる（手動バックアップと同一経路を注入する）。
  final Future<String> Function() buildCurrentJson;

  /// 既存のバックアップ復元経路で JSON を適用する。
  final Future<void> Function(String json) applyBackup;

  /// 設定の適用可否まで渡せる復元経路（未指定なら [applyBackup] を使う）。
  final Future<void> Function(String json, {bool includeSettings})?
      applyBackupWithOptions;

  /// 設定を適用した後の後始末（通知の再予約など）。
  ///
  /// 投げっぱなしで呼び、例外は握る（復元の成否に影響させない）。
  final Future<void> Function()? onSettingsRestored;

  /// 現在時刻（世代名の決定に使う）。
  final DateTime Function() _now;

  /// 自動バックアップの掟。
  final AutoBackupPolicy policy;

  /// 実装を生成する。
  AutoBackupRestorerImpl({
    required this.store,
    required this.buildCurrentJson,
    required this.applyBackup,
    this.applyBackupWithOptions,
    this.onSettingsRestored,
    this.policy = const AutoBackupPolicy(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) =>
      restoreWithOptions(fileName);

  @override
  Future<AutoBackupRestoreResult> restoreWithOptions(
    String fileName, {
    bool includeSettings = true,
  }) async {
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

      final withOptions = applyBackupWithOptions;
      if (withOptions == null) {
        await applyBackup(content!);
      } else {
        await withOptions(content!, includeSettings: includeSettings);
      }

      if (includeSettings) {
        final hook = onSettingsRestored;
        if (hook != null) {
          unawaited(_runQuietly(hook));
        }
      }
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

  /// 後始末を投げっぱなしで実行し、例外は握る。
  Future<void> _runQuietly(Future<void> Function() hook) async {
    try {
      await hook();
    } catch (_) {
      // 設定は復元済み。通知の再予約失敗で復元結果を落とさない。
    }
  }
}
