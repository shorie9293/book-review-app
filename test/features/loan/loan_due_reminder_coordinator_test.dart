import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_coordinator.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_service.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';

class _RecordingScheduler implements LoanDueReminderScheduler {
  int cancelCount = 0;
  final List<({String body, int hour, int minute})> schedules = [];

  @override
  Future<void> schedule({
    required String body,
    required int hour,
    required int minute,
  }) async {
    schedules.add((body: body, hour: hour, minute: minute));
  }

  @override
  Future<void> cancel() async => cancelCount++;
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
  DateTime day(int offset) => DateTime(2026, 9, 18 + offset, 12);

  BookLoan loan({
    required String id,
    DateTime? dueAt,
    DateTime? returnedAt,
    String bookId = 'b1',
  }) =>
      BookLoan(
        id: id,
        bookId: bookId,
        borrower: '借り手',
        lentAt: day(-10),
        dueAt: dueAt,
        returnedAt: returnedAt,
      );

  LoanDueReminderCoordinator build({
    required LoanDueReminderSettings settings,
    required List<BookLoan> loans,
    required LoanDueReminderScheduler scheduler,
    Future<Map<String, String>> Function()? bookTitleLoader,
  }) {
    return LoanDueReminderCoordinator(
      settingsRepository: InMemoryLoanDueReminderRepository(settings),
      loanRepository: _FakeLoanRepository(loans),
      scheduler: scheduler,
      clock: () => now,
      bookTitleLoader: bookTitleLoader,
    );
  }

  test('OFF なら cancel のみ・schedule は呼ばず空プラン', () async {
    final scheduler = _RecordingScheduler();
    final coordinator = build(
      settings: LoanDueReminderSettings.defaults(),
      loans: [loan(id: 'l1', dueAt: day(0))],
      scheduler: scheduler,
    );

    final plan = await coordinator.reschedule();

    expect(plan.isEmpty, isTrue);
    expect(plan.alerts, isEmpty);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.schedules, isEmpty);
  });

  test('ON + 期限超過/当日/明日 → 本文が build と完全一致し hour/minute は設定値',
      () async {
    final scheduler = _RecordingScheduler();
    final loans = [
      loan(id: 'l1', bookId: 'b1', dueAt: day(-3)),
      loan(id: 'l2', bookId: 'b2', dueAt: day(0)),
      loan(id: 'l3', bookId: 'b3', dueAt: day(1)),
    ];
    final settings = LoanDueReminderSettings(enabled: true, hour: 7, minute: 30);
    final coordinator = build(
      settings: settings,
      loans: loans,
      scheduler: scheduler,
    );

    final plan = await coordinator.reschedule();

    expect(plan.count, 3);
    expect(scheduler.cancelCount, 0);
    expect(scheduler.schedules, hasLength(1));
    final expected = LoanDueReminderService.build(loans: loans, now: now);
    expect(scheduler.schedules.single.body, expected.body);
    expect(scheduler.schedules.single.body, plan.body);
    expect(scheduler.schedules.single.hour, 7);
    expect(scheduler.schedules.single.minute, 30);
  });

  test('ON でも対象なし（2日以上先/返却済み/dueAt null）なら cancel のみ', () async {
    final scheduler = _RecordingScheduler();
    final coordinator = build(
      settings: LoanDueReminderSettings(enabled: true),
      loans: [
        loan(id: 'l1', dueAt: day(2)),
        loan(id: 'l2', dueAt: day(-1), returnedAt: day(-1)),
        loan(id: 'l3'),
      ],
      scheduler: scheduler,
    );

    final plan = await coordinator.reschedule();

    expect(plan.isEmpty, isTrue);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.schedules, isEmpty);
  });

  test('bookTitleLoader の書名が本文に反映される', () async {
    final scheduler = _RecordingScheduler();
    final coordinator = build(
      settings: LoanDueReminderSettings(enabled: true),
      loans: [loan(id: 'l1', bookId: 'b1', dueAt: day(0))],
      scheduler: scheduler,
      bookTitleLoader: () async => {'b1': 'ガリア戦記'},
    );

    await coordinator.reschedule();

    expect(scheduler.schedules.single.body, contains('ガリア戦記'));
  });

  test('bookTitleLoader が例外を投げても落ちず bookId で通知する', () async {
    final scheduler = _RecordingScheduler();
    final coordinator = build(
      settings: LoanDueReminderSettings(enabled: true),
      loans: [loan(id: 'l1', bookId: 'b1', dueAt: day(0))],
      scheduler: scheduler,
      bookTitleLoader: () async => throw StateError('boom'),
    );

    final plan = await coordinator.reschedule();

    expect(plan.count, 1);
    expect(scheduler.schedules.single.body, contains('b1'));
  });
}
