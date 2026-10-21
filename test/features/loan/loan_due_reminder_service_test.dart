import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// テスト基準日時（ローカル時刻）。
final DateTime _now = DateTime(2026, 10, 21, 9, 0);

BookLoan _loan({
  required String id,
  required String bookId,
  required DateTime? dueAt,
  DateTime? returnedAt,
}) {
  return BookLoan(
    id: id,
    bookId: bookId,
    borrower: '山田',
    lentAt: DateTime(2026, 10, 1, 10),
    dueAt: dueAt,
    returnedAt: returnedAt,
  );
}

void main() {
  group('LoanDueAlertKind', () {
    test('label', () {
      expect(LoanDueAlertKind.overdue.label, '期限超過');
      expect(LoanDueAlertKind.today.label, '本日返却');
      expect(LoanDueAlertKind.tomorrow.label, '明日返却');
    });
  });

  group('LoanDueAlert', () {
    test('overdue の label は日数を含む', () {
      final alert = LoanDueAlert(
        loanId: 'l1',
        bookId: 'b1',
        bookTitle: 'ガリア戦記',
        kind: LoanDueAlertKind.overdue,
        daysOverdue: 3,
      );
      expect(alert.label, '期限超過（3日）');
      expect(alert.line, '・ガリア戦記 — 期限超過（3日）');
    });

    test('today / tomorrow の label', () {
      final today = LoanDueAlert(
        loanId: 'l1',
        bookId: 'b1',
        bookTitle: '吾輩は猫である',
        kind: LoanDueAlertKind.today,
        daysOverdue: 0,
      );
      expect(today.label, '本日返却');
      expect(today.line, '・吾輩は猫である — 本日返却');

      final tomorrow = LoanDueAlert(
        loanId: 'l2',
        bookId: 'b2',
        bookTitle: 'こころ',
        kind: LoanDueAlertKind.tomorrow,
        daysOverdue: 0,
      );
      expect(tomorrow.label, '明日返却');
      expect(tomorrow.line, '・こころ — 明日返却');
    });

    test('bookTitle が空なら bookId を表示する', () {
      final alert = LoanDueAlert(
        loanId: 'l1',
        bookId: 'b1',
        bookTitle: '',
        kind: LoanDueAlertKind.today,
        daysOverdue: 0,
      );
      expect(alert.line, '・b1 — 本日返却');
    });
  });

  group('LoanDueReminderService.build', () {
    test('空リストは isEmpty / count 0 / body 空文字', () {
      final plan = LoanDueReminderService.build(loans: const [], now: _now);
      expect(plan.alerts, isEmpty);
      expect(plan.isEmpty, isTrue);
      expect(plan.count, 0);
      expect(plan.body, '');
    });

    test('返却済みは対象外', () {
      final plan = LoanDueReminderService.build(
        loans: [
          _loan(
            id: 'l1',
            bookId: 'b1',
            dueAt: DateTime(2026, 10, 18),
            returnedAt: DateTime(2026, 10, 19),
          ),
        ],
        now: _now,
      );
      expect(plan.isEmpty, isTrue);
    });

    test('dueAt null は対象外', () {
      final plan = LoanDueReminderService.build(
        loans: [_loan(id: 'l1', bookId: 'b1', dueAt: null)],
        now: _now,
      );
      expect(plan.isEmpty, isTrue);
    });

    test('2日以上先は対象外', () {
      final plan = LoanDueReminderService.build(
        loans: [
          _loan(id: 'l1', bookId: 'b1', dueAt: DateTime(2026, 10, 23)),
          _loan(id: 'l2', bookId: 'b2', dueAt: DateTime(2026, 10, 30)),
        ],
        now: _now,
      );
      expect(plan.isEmpty, isTrue);
    });

    test('overdue / today / tomorrow を分類し daysOverdue を算出', () {
      final plan = LoanDueReminderService.build(
        loans: [
          _loan(id: 'l1', bookId: 'b1', dueAt: DateTime(2026, 10, 18)),
          _loan(id: 'l2', bookId: 'b2', dueAt: DateTime(2026, 10, 21, 23, 59)),
          _loan(id: 'l3', bookId: 'b3', dueAt: DateTime(2026, 10, 22, 0, 1)),
        ],
        now: _now,
      );
      expect(plan.count, 3);
      expect(plan.alerts[0].loanId, 'l1');
      expect(plan.alerts[0].kind, LoanDueAlertKind.overdue);
      expect(plan.alerts[0].daysOverdue, 3);
      expect(plan.alerts[1].loanId, 'l2');
      expect(plan.alerts[1].kind, LoanDueAlertKind.today);
      expect(plan.alerts[1].daysOverdue, 0);
      expect(plan.alerts[2].loanId, 'l3');
      expect(plan.alerts[2].kind, LoanDueAlertKind.tomorrow);
      expect(plan.alerts[2].daysOverdue, 0);
    });

    test('now の時刻部分は判定に影響しない', () {
      final plan = LoanDueReminderService.build(
        loans: [_loan(id: 'l1', bookId: 'b1', dueAt: DateTime(2026, 10, 21))],
        now: DateTime(2026, 10, 21, 23, 59),
      );
      expect(plan.alerts.single.kind, LoanDueAlertKind.today);
    });

    test('ソート: overdue 先頭・daysOverdue 降順・loanId タイブレーク・today・tomorrow', () {
      final plan = LoanDueReminderService.build(
        loans: [
          _loan(id: 'l-tomorrow', bookId: 'b5', dueAt: DateTime(2026, 10, 22)),
          _loan(id: 'l-today', bookId: 'b4', dueAt: DateTime(2026, 10, 21)),
          _loan(id: 'c-1day', bookId: 'b3', dueAt: DateTime(2026, 10, 20)),
          _loan(id: 'b-3days', bookId: 'b2', dueAt: DateTime(2026, 10, 18)),
          _loan(id: 'a-3days', bookId: 'b1', dueAt: DateTime(2026, 10, 18)),
          _loan(id: 'd-5days', bookId: 'b6', dueAt: DateTime(2026, 10, 16)),
        ],
        now: _now,
      );
      expect(
        plan.alerts.map((a) => a.loanId).toList(),
        ['d-5days', 'a-3days', 'b-3days', 'c-1day', 'l-today', 'l-tomorrow'],
      );
      expect(
        plan.alerts.map((a) => a.daysOverdue).toList(),
        [5, 3, 3, 1, 0, 0],
      );
    });

    test('bookTitles を引き、無い場合は bookId を表示', () {
      final plan = LoanDueReminderService.build(
        loans: [
          _loan(id: 'l1', bookId: 'b1', dueAt: DateTime(2026, 10, 18)),
          _loan(id: 'l2', bookId: 'b2', dueAt: DateTime(2026, 10, 21)),
        ],
        now: _now,
        bookTitles: const {'b1': 'ガリア戦記'},
      );
      expect(plan.alerts[0].bookTitle, 'ガリア戦記');
      expect(plan.alerts[1].bookTitle, 'b2');
      expect(plan.body, '📚 返却期限のお知らせ\n'
          '・ガリア戦記 — 期限超過（3日）\n'
          '・b2 — 本日返却\n'
          '合計 2件');
    });

    test('body は仕様通りの完全一致文字列（末尾改行なし）', () {
      final plan = LoanDueReminderService.build(
        loans: [
          _loan(id: 'l1', bookId: 'b1', dueAt: DateTime(2026, 10, 18)),
          _loan(id: 'l2', bookId: 'b2', dueAt: DateTime(2026, 10, 21)),
        ],
        now: _now,
        bookTitles: const {'b1': 'ガリア戦記', 'b2': '吾輩は猫である'},
      );
      const expected = '📚 返却期限のお知らせ\n'
          '・ガリア戦記 — 期限超過（3日）\n'
          '・吾輩は猫である — 本日返却\n'
          '合計 2件';
      expect(plan.body, expected);
      expect(plan.body.endsWith('\n'), isFalse);
    });

    test('alerts は不変リスト', () {
      final plan = LoanDueReminderService.build(
        loans: [_loan(id: 'l1', bookId: 'b1', dueAt: DateTime(2026, 10, 18))],
        now: _now,
      );
      expect(
        () => plan.alerts.add(plan.alerts.first),
        throwsUnsupportedError,
      );
    });
  });
}
