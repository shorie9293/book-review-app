import 'app_lock_service.dart';
import 'lock_recovery_policy.dart';

/// 回復要求の結果区分。
enum LockRecoveryOutcome {
  /// 実行条件を満たさず何も変更しなかった。
  rejected,

  /// ロックを解除した（データ初期化の成否は [LockRecoveryResult.dataWiped]）。
  recovered,
}

/// 回復1回分の結果。
class LockRecoveryResult {
  /// 結果区分。
  final LockRecoveryOutcome outcome;

  /// バックアップ書き出しに失敗したか。
  final bool backupFailed;

  /// データ初期化まで完了したか。
  final bool dataWiped;

  /// 実行条件を満たさず拒否した結果。
  const LockRecoveryResult.rejected()
      : outcome = LockRecoveryOutcome.rejected,
        backupFailed = false,
        dataWiped = false;

  /// ロックを解除した結果。
  const LockRecoveryResult.recovered({
    this.backupFailed = false,
    this.dataWiped = false,
  }) : outcome = LockRecoveryOutcome.recovered;

  /// ロック解除まで到達したか。
  bool get isRecovered => outcome == LockRecoveryOutcome.recovered;
}

/// パスコード忘却時の回復導線を司る。
///
/// 順序は「バックアップ書き出し（最善努力）→ ロック解除 → データ初期化」。
/// 初期化が失敗してもロック解除は取り消さない（fail-safe）。
/// 例外は上位へ伝播させない。
class LockRecoveryService {
  final AppLockService _lockService;

  /// 事前バックアップの書き出し（null なら試行しない）。
  final Future<void> Function()? backupExporter;

  /// 全データ初期化（null なら実行しない）。
  final Future<void> Function()? dataEraser;

  LockRecoveryService(
    this._lockService, {
    this.backupExporter,
    this.dataEraser,
  });

  /// 二段確認を経た回復を実行する。
  ///
  /// ロック無効・確認語不一致なら [LockRecoveryResult.rejected] を返し、
  /// バックアップも初期化も一切行わない。
  Future<LockRecoveryResult> recover({required String confirmation}) async {
    if (!LockRecoveryPolicy.canRecover(enabled: _lockService.isLocked)) {
      return const LockRecoveryResult.rejected();
    }
    if (!LockRecoveryPolicy.isConfirmationValid(confirmation)) {
      return const LockRecoveryResult.rejected();
    }

    var backupFailed = false;
    final exporter = backupExporter;
    if (exporter != null) {
      try {
        await exporter();
      } catch (_) {
        backupFailed = true;
      }
    }

    // 失念時の出口なので、解除だけは必ず試みる（例外は握る）。
    try {
      await _lockService.disable();
    } catch (_) {
      // 解除に失敗しても初期化は続行し、上位へは投げない。
    }

    var dataWiped = false;
    final eraser = dataEraser;
    if (eraser != null) {
      try {
        await eraser();
        dataWiped = true;
      } catch (_) {
        dataWiped = false;
      }
    }

    return LockRecoveryResult.recovered(
      backupFailed: backupFailed,
      dataWiped: dataWiped,
    );
  }
}
