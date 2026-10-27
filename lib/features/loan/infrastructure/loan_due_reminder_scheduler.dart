import 'package:book_review_app/features/reminder/domain/quiet_hours_service.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_service.dart';
import 'package:book_review_app/features/reminder/infrastructure/quiet_hours_guard_wiring.dart';

/// 返却期限リマインダーの通知スケジュール抽象。
///
/// 具現化（flutter_local_notifications）を試練から切り離すための境界。
abstract class LoanDueReminderScheduler {
  /// [hour]:[minute] に毎日繰り返す通知を1件だけ登録する。
  Future<void> schedule({
    required String body,
    required int hour,
    required int minute,
  });

  /// 登録済みの返却期限通知を全て解除する。
  Future<void> cancel();
}

/// [BookNotificationService] へ委譲するだけの実装。
///
/// 送出時刻は [QuietHoursGuard] を通す。
/// - defer: 静穏時間の終了時刻へ繰り延べる
/// - skip : 登録しない（通知を送出しない）
class NotificationServiceLoanDueReminderScheduler
    implements LoanDueReminderScheduler {
  NotificationServiceLoanDueReminderScheduler({
    BookNotificationService? service,
    QuietHoursGuard? guard,
    DateTime Function()? now,
  })  : _service = service,
        _guard = guard ?? QuietHoursGuardWiring.create(),
        _now = now ?? DateTime.now;

  final BookNotificationService? _service;
  final QuietHoursGuard _guard;
  final DateTime Function() _now;

  late final BookNotificationService _resolved =
      _service ?? BookNotificationService(guard: _guard);

  /// 静穏時間を適用した時・分。null は「送出しない」。
  Future<({int hour, int minute})?> _resolveClock(int hour, int minute) async {
    try {
      final anchor = QuietHoursService.anchorAt(_now(), hour, minute);
      final adjusted = await _guard.adjust(anchor);
      if (adjusted == null) return null;
      return (hour: adjusted.hour, minute: adjusted.minute);
    } catch (_) {
      return (hour: hour, minute: minute);
    }
  }

  @override
  Future<void> schedule({
    required String body,
    required int hour,
    required int minute,
  }) async {
    final resolved = await _resolveClock(hour, minute);
    if (resolved == null) {
      await cancel();
      return;
    }
    return _resolved.scheduleLoanDueReminder(
      body: body,
      hour: resolved.hour,
      minute: resolved.minute,
    );
  }

  @override
  Future<void> cancel() => _resolved.cancelLoanDueReminder();
}
