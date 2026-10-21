import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_service.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';

/// 設定・貸出・通知スケジューラを突き合わせる調整役。
///
/// `settings.enabled == false` または対象アラート0件のときは必ず
/// [LoanDueReminderScheduler.cancel] を通す（OFF/対象なし経路の解除漏れ防止）。
class LoanDueReminderCoordinator {
  LoanDueReminderCoordinator({
    required LoanDueReminderRepository settingsRepository,
    required BookLoanRepository loanRepository,
    required LoanDueReminderScheduler scheduler,
    DateTime Function()? clock,
    Future<Map<String, String>> Function()? bookTitleLoader,
  })  : _settingsRepository = settingsRepository,
        _loanRepository = loanRepository,
        _scheduler = scheduler,
        _clock = clock ?? DateTime.now,
        _bookTitleLoader = bookTitleLoader;

  final LoanDueReminderRepository _settingsRepository;
  final BookLoanRepository _loanRepository;
  final LoanDueReminderScheduler _scheduler;
  final DateTime Function() _clock;
  final Future<Map<String, String>> Function()? _bookTitleLoader;

  /// 設定と貸出を読み直し、通知を登録または解除して計画を返す。
  Future<LoanDueReminderPlan> reschedule() async {
    final settings = await _settingsRepository.load();
    if (!settings.enabled) {
      await _scheduler.cancel();
      return const LoanDueReminderPlan.empty();
    }

    final loans = await _loanRepository.loadLoans();

    var titles = const <String, String>{};
    final loader = _bookTitleLoader;
    if (loader != null) {
      try {
        titles = await loader();
      } catch (_) {
        titles = const <String, String>{};
      }
    }

    final plan = LoanDueReminderService.build(
      loans: loans,
      now: _clock(),
      bookTitles: titles,
    );

    if (plan.isEmpty) {
      await _scheduler.cancel();
    } else {
      await _scheduler.schedule(
        body: plan.body,
        hour: settings.hour,
        minute: settings.minute,
      );
    }
    return plan;
  }
}
