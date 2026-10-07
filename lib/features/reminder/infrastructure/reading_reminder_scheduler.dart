import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_service.dart';

/// 通知スケジューラの抽象。画面はこの抽象にのみ依存する（テストでフェイク注入可）。
abstract class ReadingReminderScheduler {
  Future<void> apply(ReadingReminderSettings s);
  Future<void> cancel();
  Future<void> sendTestNotification();
}

/// [BookNotificationService] へ処理を委譲する薄い実装。
class NotificationServiceReadingReminderScheduler
    implements ReadingReminderScheduler {
  NotificationServiceReadingReminderScheduler({BookNotificationService? service})
      : _service = service ?? BookNotificationService();

  final BookNotificationService _service;

  @override
  Future<void> apply(ReadingReminderSettings s) async {
    if (!s.enabled) {
      await cancel();
      return;
    }
    await _service.scheduleReadingReminder(
      hour: s.hour,
      minute: s.minute,
      weekdays: s.weekdays,
    );
  }

  @override
  Future<void> cancel() => _service.cancelReadingReminder();

  @override
  Future<void> sendTestNotification() => _service.sendTestNotification();
}
