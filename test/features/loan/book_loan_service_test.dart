import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/features/loan/domain/book_loan_service.dart';

void main() {
  DateTime d(int y, int m, int day, [int h = 0]) =>
      DateTime.utc(y, m, day, h).toLocal();

  BookLoan loan({
    required String id,
    String bookId = 'b1',
    String borrower = '山田太郎',
    DateTime? lentAt,
    DateTime? dueAt,
    DateTime? returnedAt,
  }) =>
      BookLoan(
        id: id,
        bookId: bookId,
        borrower: borrower,
        lentAt: lentAt ?? d(2026, 10, 1),
        dueAt: dueAt,
        returnedAt: returnedAt,
      );

  final now = d(2026, 10, 20, 10);

  // 境界は now のローカル暦日から相対生成する（TZ 非依存）。
  DateTime dayOffset(int days, [int hour = 0]) =>
      DateTime(now.year, now.month, now.day + days, hour);

  group('LoanBucket ラベル', () {
    test('5値すべてに日本語 label がある', () {
      expect(LoanBucket.values.length, 5);
      expect(LoanBucket.none.label, isNotEmpty);
      expect(LoanBucket.overdue.label, isNotEmpty);
      expect(LoanBucket.today.label, isNotEmpty);
      expect(LoanBucket.soon.label, isNotEmpty);
      expect(LoanBucket.later.label, isNotEmpty);
    });
  });

  group('activeLoans', () {
    test('未返却のみを返す', () {
      final loans = [
        loan(id: 'a', dueAt: d(2026, 10, 25)),
        loan(id: 'b', dueAt: d(2026, 10, 25), returnedAt: d(2026, 10, 15)),
      ];
      expect(BookLoanService.activeLoans(loans).map((e) => e.id), ['a']);
    });

    test('dueAt 昇順・null は末尾', () {
      final loans = [
        loan(id: 'no-due'),
        loan(id: 'late', dueAt: d(2026, 10, 29), lentAt: d(2026, 10, 2)),
        loan(id: 'early', dueAt: d(2026, 10, 21), lentAt: d(2026, 10, 2)),
      ];
      expect(BookLoanService.activeLoans(loans).map((e) => e.id),
          ['early', 'late', 'no-due']);
    });

    test('同一 dueAt は lentAt 昇順でタイブレーク', () {
      final due = d(2026, 10, 25);
      final loans = [
        loan(id: 'newer', dueAt: due, lentAt: d(2026, 10, 5)),
        loan(id: 'older', dueAt: due, lentAt: d(2026, 10, 2)),
      ];
      expect(BookLoanService.activeLoans(loans).map((e) => e.id),
          ['older', 'newer']);
    });

    test('dueAt も lentAt も同じなら id 昇順', () {
      final due = d(2026, 10, 25);
      final lent = d(2026, 10, 2);
      final loans = [
        loan(id: 'z', dueAt: due, lentAt: lent),
        loan(id: 'a', dueAt: due, lentAt: lent),
      ];
      expect(BookLoanService.activeLoans(loans).map((e) => e.id), ['a', 'z']);
    });

    test('入力リストを破壊しない', () {
      final loans = [
        loan(id: 'b', dueAt: d(2026, 10, 25)),
        loan(id: 'a', dueAt: d(2026, 10, 21)),
      ];
      BookLoanService.activeLoans(loans);
      expect(loans.map((e) => e.id), ['b', 'a']);
    });

    test('空リストは空', () {
      expect(BookLoanService.activeLoans([]), isEmpty);
    });

    test('返却済をすべて除外する', () {
      final loans = [
        loan(id: 'a', returnedAt: d(2026, 10, 1)),
        loan(id: 'b', returnedAt: d(2026, 10, 2)),
      ];
      expect(BookLoanService.activeLoans(loans), isEmpty);
    });
  });

  group('returnedLoans', () {
    test('返却済のみを返す', () {
      final loans = [
        loan(id: 'a', returnedAt: d(2026, 10, 10)),
        loan(id: 'b'),
      ];
      expect(BookLoanService.returnedLoans(loans).map((e) => e.id), ['a']);
    });

    test('returnedAt 降順・同時刻は id 昇順', () {
      final at = d(2026, 10, 12);
      final loans = [
        loan(id: 'b', returnedAt: at),
        loan(id: 'a', returnedAt: at),
        loan(id: 'old', returnedAt: d(2026, 10, 1)),
      ];
      expect(BookLoanService.returnedLoans(loans).map((e) => e.id),
          ['a', 'b', 'old']);
    });

    test('非破壊', () {
      final loans = [
        loan(id: 'a', returnedAt: d(2026, 10, 1)),
        loan(id: 'b', returnedAt: d(2026, 10, 2)),
      ];
      BookLoanService.returnedLoans(loans);
      expect(loans.map((e) => e.id), ['a', 'b']);
    });
  });

  group('overdueLoans', () {
    test('dueAt が today0時より前のみ', () {
      final loans = [
        loan(id: 'yesterday', dueAt: dayOffset(-1, 23)),
        loan(id: 'today', dueAt: dayOffset(0)),
        loan(id: 'future', dueAt: dayOffset(5)),
      ];
      expect(BookLoanService.overdueLoans(loans, now: now).map((e) => e.id),
          ['yesterday']);
    });

    test('今日0時ちょうどは超過ではない', () {
      final loans = [loan(id: 'today', dueAt: dayOffset(0))];
      expect(BookLoanService.overdueLoans(loans, now: now), isEmpty);
    });

    test('返却済は期限超過でも除外', () {
      final loans = [
        loan(id: 'r', dueAt: dayOffset(-20), returnedAt: dayOffset(-15)),
      ];
      expect(BookLoanService.overdueLoans(loans, now: now), isEmpty);
    });

    test('dueAt null は超過に含めない', () {
      expect(BookLoanService.overdueLoans([loan(id: 'x')], now: now), isEmpty);
    });

    test('非破壊', () {
      final loans = [loan(id: 'a', dueAt: dayOffset(-19))];
      BookLoanService.overdueLoans(loans, now: now);
      expect(loans.single.id, 'a');
    });
  });

  group('dueSoonLoans', () {
    test('今日0時〜7日後0時の手前までを含む', () {
      final loans = [
        loan(id: 'today0', dueAt: dayOffset(0)),
        loan(id: 'plus3', dueAt: dayOffset(3)),
        loan(id: 'plus7', dueAt: dayOffset(7)),
      ];
      expect(BookLoanService.dueSoonLoans(loans, now: now).map((e) => e.id),
          ['today0', 'plus3']);
    });

    test('期限超過は除外', () {
      final loans = [
        loan(id: 'over', dueAt: dayOffset(-1)),
        loan(id: 'soon', dueAt: dayOffset(2)),
      ];
      expect(BookLoanService.dueSoonLoans(loans, now: now).map((e) => e.id),
          ['soon']);
    });

    test('withinDays を指定できる', () {
      final loans = [
        loan(id: 'plus1', dueAt: dayOffset(1)),
        loan(id: 'plus5', dueAt: dayOffset(5)),
      ];
      expect(
        BookLoanService.dueSoonLoans(loans, now: now, withinDays: 2)
            .map((e) => e.id),
        ['plus1'],
      );
    });

    test('dueAt null と返却済は除外', () {
      final loans = [
        loan(id: 'none'),
        loan(id: 'ret', dueAt: dayOffset(1), returnedAt: dayOffset(-5)),
      ];
      expect(BookLoanService.dueSoonLoans(loans, now: now), isEmpty);
    });
  });

  group('bucketOf', () {
    test('返却済は none', () {
      final l = loan(id: 'a', dueAt: dayOffset(-19), returnedAt: dayOffset(-18));
      expect(BookLoanService.bucketOf(l, now: now), LoanBucket.none);
    });

    test('dueAt null は later', () {
      expect(BookLoanService.bucketOf(loan(id: 'a'), now: now), LoanBucket.later);
    });

    test('期限超過は overdue', () {
      final l = loan(id: 'a', dueAt: dayOffset(-1));
      expect(BookLoanService.bucketOf(l, now: now), LoanBucket.overdue);
    });

    test('当日は today', () {
      final l = loan(id: 'a', dueAt: dayOffset(0));
      expect(BookLoanService.bucketOf(l, now: now), LoanBucket.today);
    });

    test('7日以内は soon', () {
      final l = loan(id: 'a', dueAt: dayOffset(6));
      expect(BookLoanService.bucketOf(l, now: now), LoanBucket.soon);
    });

    test('8日以降は later', () {
      final l = loan(id: 'a', dueAt: dayOffset(8));
      expect(BookLoanService.bucketOf(l, now: now), LoanBucket.later);
    });

    test('withinDays を指定できる', () {
      final l = loan(id: 'a', dueAt: dayOffset(3));
      expect(BookLoanService.bucketOf(l, now: now, withinDays: 2),
          LoanBucket.later);
    });
  });

  group('activeLoanFor', () {
    test('未返却のうち lentAt 最新を返す', () {
      final loans = [
        loan(id: 'old', bookId: 'b1', lentAt: d(2026, 9, 1)),
        loan(id: 'new', bookId: 'b1', lentAt: d(2026, 10, 1)),
      ];
      expect(BookLoanService.activeLoanFor(loans, 'b1')?.id, 'new');
    });

    test('同時刻は id 昇順で最後', () {
      final lent = d(2026, 10, 1);
      final loans = [
        loan(id: 'b', bookId: 'b1', lentAt: lent),
        loan(id: 'a', bookId: 'b1', lentAt: lent),
      ];
      expect(BookLoanService.activeLoanFor(loans, 'b1')?.id, 'b');
    });

    test('返却済は無視する', () {
      final loans = [
        loan(id: 'ret', bookId: 'b1', lentAt: d(2026, 10, 5),
            returnedAt: d(2026, 10, 6)),
        loan(id: 'old', bookId: 'b1', lentAt: d(2026, 10, 1)),
      ];
      expect(BookLoanService.activeLoanFor(loans, 'b1')?.id, 'old');
    });

    test('該当なしは null', () {
      expect(BookLoanService.activeLoanFor([loan(id: 'a')], 'zzz'), isNull);
    });
  });

  group('addLoan', () {
    test('非破壊で追加する', () {
      final loans = [loan(id: 'a', bookId: 'b1')];
      final result = BookLoanService.addLoan(loans, loan(id: 'b', bookId: 'b2'));
      expect(result.length, 2);
      expect(loans.length, 1);
    });

    test('同一 bookId に未返却があれば ArgumentError', () {
      final loans = [loan(id: 'a', bookId: 'b1')];
      expect(
        () => BookLoanService.addLoan(loans, loan(id: 'b', bookId: 'b1')),
        throwsArgumentError,
      );
    });

    test('同一 bookId でも既存が返却済なら追加できる', () {
      final loans = [
        loan(id: 'a', bookId: 'b1', returnedAt: d(2026, 10, 5)),
      ];
      final result = BookLoanService.addLoan(loans, loan(id: 'b', bookId: 'b1'));
      expect(result.map((e) => e.id), ['a', 'b']);
    });

    test('空リストにも追加できる', () {
      final result = BookLoanService.addLoan([], loan(id: 'a'));
      expect(result.single.id, 'a');
    });
  });

  group('markReturned', () {
    test('該当 id の returnedAt を設定する', () {
      final loans = [loan(id: 'a'), loan(id: 'b')];
      final result =
          BookLoanService.markReturned(loans, 'b', d(2026, 10, 20, 12));
      expect(result.firstWhere((e) => e.id == 'b').returnedAt,
          d(2026, 10, 20, 12));
      expect(result.firstWhere((e) => e.id == 'a').isReturned, isFalse);
    });

    test('未知 id は例外なく同内容の新リスト', () {
      final loans = [loan(id: 'a')];
      final result = BookLoanService.markReturned(loans, 'zzz', now);
      expect(result, loans);
      expect(identical(result, loans), isFalse);
    });

    test('非破壊', () {
      final loans = [loan(id: 'a')];
      BookLoanService.markReturned(loans, 'a', now);
      expect(loans.single.isReturned, isFalse);
    });
  });

  group('search', () {
    final loans = [
      loan(id: '1', borrower: '山田 太郎'),
      loan(id: '2', borrower: 'ＡＢＣ商店'),
      loan(id: '3', borrower: 'john smith'),
    ];

    test('部分一致で絞り込む', () {
      expect(BookLoanService.search(loans, '太郎').map((e) => e.id), ['1']);
    });

    test('大文字小文字を区別しない', () {
      expect(BookLoanService.search(loans, 'JOHN').map((e) => e.id), ['3']);
    });

    test('全角英数を半角に正規化する', () {
      expect(BookLoanService.search(loans, 'abc').map((e) => e.id), ['2']);
    });

    test('全角スペースを半角に正規化する', () {
      expect(BookLoanService.search(loans, '山田　太郎').map((e) => e.id),
          ['1']);
    });

    test('前後空白を trim する', () {
      expect(BookLoanService.search(loans, '  john  ').map((e) => e.id),
          ['3']);
    });

    test('空クエリは全件', () {
      expect(BookLoanService.search(loans, '   ').length, 3);
    });

    test('一致なしは空', () {
      expect(BookLoanService.search(loans, 'zzz'), isEmpty);
    });

    test('非破壊', () {
      BookLoanService.search(loans, '太郎');
      expect(loans.length, 3);
    });
  });

  group('dueLabel', () {
    test('返却済は返却済', () {
      final l = loan(id: 'a', returnedAt: d(2026, 10, 1));
      expect(BookLoanService.dueLabel(l, now: now), '返却済');
    });

    test('dueAt null は期限なし', () {
      expect(BookLoanService.dueLabel(loan(id: 'a'), now: now), '期限なし');
    });

    test('1日超過は期限超過 1日', () {
      final l = loan(id: 'a', dueAt: dayOffset(-1));
      expect(BookLoanService.dueLabel(l, now: now), '期限超過 1日');
    });

    test('3日超過は期限超過 3日', () {
      final l = loan(id: 'a', dueAt: dayOffset(-3));
      expect(BookLoanService.dueLabel(l, now: now), '期限超過 3日');
    });

    test('当日は本日返却', () {
      final l = loan(id: 'a', dueAt: dayOffset(0));
      expect(BookLoanService.dueLabel(l, now: now), '本日返却');
    });

    test('3日後はあと3日', () {
      final l = loan(id: 'a', dueAt: dayOffset(3));
      expect(BookLoanService.dueLabel(l, now: now), 'あと3日');
    });
  });

  group('summaryLabel', () {
    test('貸出中と期限超過を表示する', () {
      final loans = [
        loan(id: 'a', dueAt: dayOffset(-1)),
        loan(id: 'b', dueAt: dayOffset(5)),
        loan(id: 'c', dueAt: dayOffset(6)),
        loan(id: 'd', dueAt: dayOffset(-19), returnedAt: dayOffset(-18)),
      ];
      expect(BookLoanService.summaryLabel(loans, now: now),
          '貸出中 3冊（期限超過 1）');
    });

    test('0件は貸出中 0冊', () {
      expect(BookLoanService.summaryLabel([], now: now), '貸出中 0冊');
    });

    test('期限超過0件なら括弧を付けない', () {
      final loans = [loan(id: 'a', dueAt: dayOffset(5))];
      expect(BookLoanService.summaryLabel(loans, now: now), '貸出中 1冊');
    });
  });
}
