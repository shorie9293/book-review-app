import 'package:book_review_app/features/loan/domain/loan_due_reminder_coordinator.dart';

/// 貸出の追加・返却・起動時に再計算を呼ぶための薄い窓口。
///
/// 失敗しても画面操作や起動を止めないよう、例外は外へ出さずに
/// 成否（bool）だけを返す。冪等性は coordinator / scheduler 側の
/// 解除→登録に委ねる（ここでは何も記録しない）。
class LoanDueReminderResync {
  LoanDueReminderResync({required LoanDueReminderCoordinator coordinator})
      : _coordinator = coordinator;

  final LoanDueReminderCoordinator _coordinator;

  /// 再計算を1回実行する。成功なら true、失敗なら false。
  Future<bool> trigger() async {
    try {
      await _coordinator.reschedule();
      return true;
    } catch (_) {
      // 通知は副次的な機能なので、失敗しても呼び出し元を止めない
      return false;
    }
  }
}
