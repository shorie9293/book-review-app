import 'package:book_review_app/features/reminder/infrastructure/notification_service.dart';

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
class NotificationServiceLoanDueReminderScheduler
    implements LoanDueReminderScheduler {
  NotificationServiceLoanDueReminderScheduler([BookNotificationService? service])
      : _service = service ?? BookNotificationService();

  final BookNotificationService _service;

  @override
  Future<void> schedule({
    required String body,
    required int hour,
    required int minute,
  }) {
    return _service.scheduleLoanDueReminder(
      body: body,
      hour: hour,
      minute: minute,
    );
  }

  @override
  Future<void> cancel() => _service.cancelLoanDueReminder();
}
