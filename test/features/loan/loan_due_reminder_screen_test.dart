import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';
import 'package:book_review_app/features/loan/presentation/loan_management_screen.dart';

class _FakeLoanRepository implements BookLoanRepository {
  _FakeLoanRepository(this.loans);

  List<BookLoan> loans;

  @override
  Future<List<BookLoan>> loadLoans() async => loans;

  @override
  Future<void> saveLoans(List<BookLoan> value) async => loans = value;
}

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

void main() {
  final now = DateTime(2026, 9, 18, 12);
  DateTime day(int offset) => DateTime(2026, 9, 18 + offset, 12);

  BookLoan loan({required String id, DateTime? dueAt}) => BookLoan(
        id: id,
        bookId: 'b-$id',
        borrower: '借り手$id',
        lentAt: day(-10),
        dueAt: dueAt,
      );

  Widget screen({
    required BookLoanRepository loans,
    LoanDueReminderRepository? reminderRepository,
    LoanDueReminderScheduler? reminderScheduler,
  }) =>
      MaterialApp(
        home: LoanManagementScreen(
          repository: loans,
          nowOverride: now,
          reminderRepository: reminderRepository,
          reminderScheduler: reminderScheduler,
        ),
      );

  testWidgets('両方 null なら通知セクションは描画されない', (tester) async {
    await tester.pumpWidget(screen(loans: _FakeLoanRepository([
      loan(id: 'l1', dueAt: day(0)),
    ])));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.loanDueReminderSection), findsNothing);
    expect(find.byKey(AppKeys.loanDueReminderSwitch), findsNothing);
  });

  testWidgets('トグル ON で enabled=true が永続化され schedule が呼ばれる',
      (tester) async {
    final repo = InMemoryLoanDueReminderRepository();
    final scheduler = _RecordingScheduler();
    await tester.pumpWidget(screen(
      loans: _FakeLoanRepository([loan(id: 'l1', dueAt: day(0))]),
      reminderRepository: repo,
      reminderScheduler: scheduler,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.loanDueReminderSection), findsOneWidget);
    expect((await repo.load()).enabled, isFalse);
    expect(scheduler.cancelCount, 1);

    await tester.tap(find.byKey(AppKeys.loanDueReminderSwitch));
    await tester.pumpAndSettle();

    final saved = await repo.load();
    expect(saved.enabled, isTrue);
    expect(scheduler.schedules, hasLength(1));
    expect(scheduler.schedules.single.body, contains('本日返却'));
    // 状態文言も件数と一致する
    expect(find.text('本日から通知: 1件'), findsOneWidget);
  });

  testWidgets('保存ボタンで時刻が永続化され schedule の hour に反映される',
      (tester) async {
    final repo = InMemoryLoanDueReminderRepository(
      LoanDueReminderSettings(enabled: true, hour: 9, minute: 0),
    );
    final scheduler = _RecordingScheduler();
    await tester.pumpWidget(screen(
      loans: _FakeLoanRepository([loan(id: 'l1', dueAt: day(0))]),
      reminderRepository: repo,
      reminderScheduler: scheduler,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.loanDueReminderHour));
    await tester.pumpAndSettle();
    await tester.tap(find.text('07:00').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.loanDueReminderSave));
    await tester.pumpAndSettle();

    final saved = await repo.load();
    expect(saved.hour, 7);
    expect(saved.enabled, isTrue);
    expect(scheduler.schedules.last.hour, 7);
    expect(scheduler.schedules.last.minute, 0);
  });

  testWidgets('対象なしなら状態文言は「対象なし」', (tester) async {
    final repo = InMemoryLoanDueReminderRepository(
      LoanDueReminderSettings(enabled: true),
    );
    final scheduler = _RecordingScheduler();
    await tester.pumpWidget(screen(
      loans: _FakeLoanRepository([loan(id: 'l1', dueAt: day(3))]),
      reminderRepository: repo,
      reminderScheduler: scheduler,
    ));
    await tester.pumpAndSettle();

    expect(find.text('対象なし'), findsOneWidget);
    expect(scheduler.schedules, isEmpty);
    expect(scheduler.cancelCount, greaterThanOrEqualTo(1));
  });
}
