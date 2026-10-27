import 'package:book_review_app/features/reminder/domain/quiet_hours_service.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_service.dart';
import 'package:book_review_app/features/reminder/infrastructure/quiet_hours_guard_wiring.dart';

/// 通知スケジューラの抽象。画面はこの抽象にのみ依存する（テストでフェイク注入可）。
abstract class ReadingReminderScheduler {
  Future<void> apply(ReadingReminderSettings s);
  Future<void> cancel();
  Future<void> sendTestNotification();
}

/// [BookNotificationService] へ処理を委譲する薄い実装。
///
/// 送出時刻は [QuietHoursGuard] を通す。
/// - defer: 静穏時間の終了時刻へ繰り延べた時・分で登録する
/// - skip : 登録しない（通知を送出しない）
///
/// [now] は試練のための現在時刻注入点（既定は [DateTime.now]）。
class NotificationServiceReadingReminderScheduler
    implements ReadingReminderScheduler {
  NotificationServiceReadingReminderScheduler({
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

  @override
  Future<void> apply(ReadingReminderSettings s) async {
    if (!s.enabled) {
      await cancel();
      return;
    }
    final resolved = await _resolveClock(s.hour, s.minute);
    if (resolved == null) {
      // 静穏時間 policy=skip: 登録もしない。
      await cancel();
      return;
    }
    await _resolved.scheduleReadingReminder(
      hour: resolved.hour,
      minute: resolved.minute,
      weekdays: s.weekdays,
    );
  }

  /// 静穏時間を適用した時・分。null は「送出しない」。
  Future<({int hour, int minute})?> _resolveClock(int hour, int minute) async {
    try {
      final anchor = QuietHoursService.anchorAt(_now(), hour, minute);
      final adjusted = await _guard.adjust(anchor);
      if (adjusted == null) return null;
      return (hour: adjusted.hour, minute: adjusted.minute);
    } catch (_) {
      // ガード失敗時は従来どおりの時刻で登録する（通知を止めない）。
      return (hour: hour, minute: minute);
    }
  }

  @override
  Future<void> cancel() => _resolved.cancelReadingReminder();

  @override
  Future<void> sendTestNotification() => _resolved.sendTestNotification();
}
