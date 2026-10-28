import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_coordinator.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_resync.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';

/// 本番経路の [LoanDueReminderResync] を組み立てる。
///
/// 設定は Hive、通知は flutter_local_notifications 実装
/// （静穏時間は本番既定のガード）を使う。
LoanDueReminderResync createHiveLoanDueReminderResync({
  required BookLoanRepository loanRepository,
  Future<Map<String, String>> Function()? bookTitleLoader,
  DateTime Function()? clock,
}) {
  return LoanDueReminderResync(
    coordinator: LoanDueReminderCoordinator(
      settingsRepository: HiveLoanDueReminderRepository(),
      loanRepository: loanRepository,
      scheduler: NotificationServiceLoanDueReminderScheduler(now: clock),
      clock: clock,
      bookTitleLoader: bookTitleLoader,
    ),
  );
}
