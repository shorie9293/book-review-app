import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_coordinator.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_resync.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';

/// 通知IDが固定である実装を模すスケジューラ。
///
/// 登録は常に同一IDを上書きするため、保持される登録は常に1件。
class _RecordingScheduler implements LoanDueReminderScheduler {
  static const int notificationId = 9001;

  int cancelCount = 0;
  final List<({String body, int hour, int minute})> schedules = [];

  /// 現在登録されている通知（固定IDごと）。
  final Map<int, ({String body, int hour, int minute})> registered = {};

  @override
  Future<void> schedule({
    required String body,
    required int hour,
    required int minute,
  }) async {
    final entry = (body: body, hour: hour, minute: minute);
    schedules.add(entry);
    registered[notificationId] = entry;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    registered.clear();
  }
}

/// schedule/cancel で必ず落ちる（coordinator から例外が漏れる）スケジューラ。
class _ThrowingScheduler implements LoanDueReminderScheduler {
  @override
  Future<void> schedule({
    required String body,
    required int hour,
    required int minute,
  }) async =>
      throw StateError('schedule failed');

  @override
  Future<void> cancel() async => throw StateError('cancel failed');
}

class _FakeLoanRepository implements BookLoanRepository {
  _FakeLoanRepository(this.loans);

  List<BookLoan> loans;

  @override
  Future<List<BookLoan>> loadLoans() async => loans;

  @override
  Future<void> saveLoans(List<BookLoan> value) async => loans = value;
}

void main() {
  final now = DateTime(2026, 9, 18, 12);

  LoanDueReminderResync build({
    required LoanDueReminderScheduler scheduler,
    LoanDueReminderSettings? settings,
    List<BookLoan>? loans,
  }) {
    return LoanDueReminderResync(
      coordinator: LoanDueReminderCoordinator(
        settingsRepository: InMemoryLoanDueReminderRepository(settings),
        loanRepository: _FakeLoanRepository(loans ?? const []),
        scheduler: scheduler,
        clock: () => now,
      ),
    );
  }

  test('trigger は coordinator.reschedule を通してスケジューラへ登録する', () async {
    final scheduler = _RecordingScheduler();
    final resync = build(
      scheduler: scheduler,
      settings: LoanDueReminderSettings(enabled: true, hour: 7, minute: 30),
      loans: [
        BookLoan(
          id: 'l1',
          bookId: 'b1',
          borrower: '田中',
          lentAt: now.subtract(const Duration(days: 10)),
          dueAt: now.add(const Duration(days: 1)),
        ),
      ],
    );

    final ok = await resync.trigger();

    expect(ok, isTrue);
    expect(scheduler.schedules, hasLength(1));
    expect(scheduler.schedules.single.hour, 7);
    expect(scheduler.schedules.single.minute, 30);
    expect(scheduler.registered, hasLength(1));
  });

  test('coordinator が投げた例外は握りつぶし false を返す（外へ漏らさない）', () async {
    final resync = build(
      scheduler: _ThrowingScheduler(),
      // OFF 経路でも cancel が投げるため例外経路に入る
      settings: LoanDueReminderSettings.defaults(),
    );

    final ok = await resync.trigger();

    expect(ok, isFalse);
  });

  test('2回連続 trigger しても登録は1件のまま（二重登録しない）', () async {
    final scheduler = _RecordingScheduler();
    final resync = build(
      scheduler: scheduler,
      settings: LoanDueReminderSettings(enabled: true),
      loans: [
        BookLoan(
          id: 'l1',
          bookId: 'b1',
          borrower: '田中',
          lentAt: now.subtract(const Duration(days: 10)),
          dueAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    );

    expect(await resync.trigger(), isTrue);
    expect(await resync.trigger(), isTrue);

    // 解除→登録の繰り返しでも通知IDは1つのまま
    expect(scheduler.schedules, hasLength(2));
    expect(scheduler.registered, hasLength(1));
  });
}
