import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_coordinator.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_service.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';
import 'package:book_review_app/features/loan/presentation/loan_management_screen.dart';

/// 親探針: 画面 → リポジトリ → 調整役 → 通知スケジューラ の合成不変条件。
///
/// 個別ユニット試練は「画面が state だけ更新して永続化しない」「返却後に
/// 通知本文が古いまま」「画面が独自集計して調整役と食い違う」型を撃てないため、
/// ここで一気通貫に撃つ。
class _RecordingScheduler implements LoanDueReminderScheduler {
  final List<Map<String, Object>> schedules = <Map<String, Object>>[];
  int cancelCount = 0;

  @override
  Future<void> schedule({
    required String body,
    required int hour,
    required int minute,
  }) async {
    schedules.add(<String, Object>{'body': body, 'hour': hour, 'minute': minute});
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  String? get lastBody =>
      schedules.isEmpty ? null : schedules.last['body'] as String;
}

void main() {
  final DateTime now = DateTime(2026, 10, 21, 9, 0);

  BookLoan loan(String id, String bookId, String borrower, DateTime? due) =>
      BookLoan(
        id: id,
        bookId: bookId,
        borrower: borrower,
        lentAt: DateTime(2026, 10, 1, 10, 0),
        dueAt: due,
      );

  List<BookLoan> seedLoans() => <BookLoan>[
        loan('l_over', 'b1', 'Aさん', DateTime(2026, 10, 18)),
        loan('l_today', 'b2', 'Bさん', DateTime(2026, 10, 21)),
        loan('l_tomorrow', 'b3', 'Cさん', DateTime(2026, 10, 22)),
        loan('l_future', 'b4', 'Dさん', DateTime(2026, 10, 30)),
      ];

  Future<Map<String, String>> titles() async => <String, String>{
        'b1': 'ガリア戦記',
        'b2': '吾輩は猫である',
        'b3': '枕草子',
        'b4': '未来の本',
      };

  Future<void> pumpScreen(
    WidgetTester tester, {
    required InMemoryBookLoanRepository loans,
    required InMemoryLoanDueReminderRepository settings,
    required _RecordingScheduler scheduler,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: LoanManagementScreen(
        repository: loans,
        nowOverride: now,
        bookTitleLoader: titles,
        reminderRepository: settings,
        reminderScheduler: scheduler,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('探針1: 画面の件数表示は調整役の計画件数と一致する（画面が独自集計しない）',
      (tester) async {
    final loans = InMemoryBookLoanRepository(seedLoans());
    final settings = InMemoryLoanDueReminderRepository(
      LoanDueReminderSettings(enabled: true, hour: 9, minute: 0),
    );
    final scheduler = _RecordingScheduler();

    await pumpScreen(tester,
        loans: loans, settings: settings, scheduler: scheduler);

    final plan = await LoanDueReminderCoordinator(
      settingsRepository: settings,
      loanRepository: loans,
      scheduler: _RecordingScheduler(),
      clock: () => now,
      bookTitleLoader: titles,
    ).reschedule();

    expect(plan.count, 3, reason: 'overdue/today/tomorrow の3件のみ');
    final status = tester
        .widget<Text>(find.byKey(AppKeys.loanDueReminderStatus))
        .data!;
    expect(status, '本日から通知: ${plan.count}件');
  });

  testWidgets('探針2: トグルONがリポジトリへ永続化され、本文がサービス出力と一致する',
      (tester) async {
    final loans = InMemoryBookLoanRepository(seedLoans());
    final settings = InMemoryLoanDueReminderRepository(
      LoanDueReminderSettings(enabled: false, hour: 7, minute: 0),
    );
    final scheduler = _RecordingScheduler();

    await pumpScreen(tester,
        loans: loans, settings: settings, scheduler: scheduler);

    // OFF の間は解除のみで予約されない。
    expect(scheduler.schedules, isEmpty);
    expect(scheduler.cancelCount, greaterThan(0));

    await tester.tap(find.byKey(AppKeys.loanDueReminderSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final saved = await settings.load();
    expect(saved.enabled, isTrue, reason: '画面の state 更新ではなく永続化に到達せよ');

    final expected = LoanDueReminderService.build(
      loans: seedLoans(),
      now: now,
      bookTitles: await titles(),
    );
    expect(scheduler.lastBody, expected.body);
    expect(scheduler.schedules.last['hour'], 7);
    expect(scheduler.schedules.last['minute'], 0);
    expect(expected.body, contains('ガリア戦記 — 期限超過（3日）'));
    expect(expected.body, isNot(contains('未来の本')), reason: '2日以上先は通知しない');
  });

  testWidgets('探針3: 画面で返却すると永続化され、通知本文からその本が消えて件数が減る',
      (tester) async {
    final loans = InMemoryBookLoanRepository(seedLoans());
    final settings = InMemoryLoanDueReminderRepository(
      LoanDueReminderSettings(enabled: true, hour: 9, minute: 0),
    );
    final scheduler = _RecordingScheduler();

    await pumpScreen(tester,
        loans: loans, settings: settings, scheduler: scheduler);
    expect(scheduler.lastBody, contains('ガリア戦記'));

    await tester.tap(find.byKey(AppKeys.loanReturnButton('l_over')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final stored = await loans.loadLoans();
    final returned = stored.firstWhere((l) => l.id == 'l_over');
    expect(returned.isReturned, isTrue, reason: '返却がリポジトリに永続化されること');

    expect(scheduler.lastBody, isNot(contains('ガリア戦記')),
        reason: '返却済みは通知本文から消えること');
    final status = tester
        .widget<Text>(find.byKey(AppKeys.loanDueReminderStatus))
        .data!;
    expect(status, '本日から通知: 2件');
  });

  testWidgets('探針4: 対象が全て返却されると予約ではなく解除が呼ばれる',
      (tester) async {
    final loans = InMemoryBookLoanRepository(<BookLoan>[
      loan('l_only', 'b9', 'Zさん', DateTime(2026, 10, 21)),
    ]);
    final settings = InMemoryLoanDueReminderRepository(
      LoanDueReminderSettings(enabled: true, hour: 9, minute: 0),
    );
    final scheduler = _RecordingScheduler();

    await pumpScreen(tester,
        loans: loans, settings: settings, scheduler: scheduler);
    expect(scheduler.schedules, hasLength(1));

    await tester.tap(find.byKey(AppKeys.loanReturnButton('l_only')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(scheduler.schedules, hasLength(1), reason: '新たな予約を積まない');
    expect(scheduler.cancelCount, greaterThanOrEqualTo(1), reason: '解除が呼ばれる');
    final status = tester
        .widget<Text>(find.byKey(AppKeys.loanDueReminderStatus))
        .data!;
    expect(status, '対象なし');
  });

  testWidgets('探針5: 依存未注入なら通知セクションは出ず既存挙動は不変', (tester) async {
    final loans = InMemoryBookLoanRepository(seedLoans());
    await tester.pumpWidget(MaterialApp(
      home: LoanManagementScreen(repository: loans, nowOverride: now),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(AppKeys.loanDueReminderSection), findsNothing);
    expect(find.byKey(AppKeys.loanRow('l_over')), findsOneWidget);
  });
}
