import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/loan/domain/book_loan_service.dart';
import 'package:book_review_app/features/loan/presentation/loan_management_screen.dart';

/// 2つのインスタンスで共有できる保存領域（「別インスタンスで読み直す」検証用）。
class SharedLoanStore {
  final Map<String, BookLoan> data = {};
}

/// 共有ストアを使うリポジトリ。別インスタンスで同じデータを読める。
class SharedLoanRepository implements BookLoanRepository {
  final SharedLoanStore store;
  int saveCount = 0;

  SharedLoanRepository([SharedLoanStore? store])
      : store = store ?? SharedLoanStore();

  @override
  Future<List<BookLoan>> loadLoans() async => store.data.values.toList();

  @override
  Future<void> saveLoans(List<BookLoan> loans) async {
    saveCount++;
    store.data
      ..clear()
      ..addEntries([for (final loan in loans) MapEntry(loan.id, loan)]);
  }
}

/// 読込完了を任意のタイミングまで遅延させるリポジトリ（ローディング検証用）。
class DelayedLoanRepository implements BookLoanRepository {
  final Future<List<BookLoan>> Function() loader;

  DelayedLoanRepository(this.loader);

  @override
  Future<List<BookLoan>> loadLoans() => loader();

  @override
  Future<void> saveLoans(List<BookLoan> loans) async {}
}

void main() {
  // TZ=UTC でも JST でも「同じ暦日」になるよう UTC から現地時刻へ変換する。
  final now = DateTime.utc(2026, 9, 18, 12).toLocal();
  DateTime day(int offsetDays) =>
      DateTime.utc(2026, 9, 18 + offsetDays, 12).toLocal();

  BookLoan loan({
    required String id,
    String bookId = 'b1',
    required String borrower,
    DateTime? dueAt,
    DateTime? returnedAt,
  }) =>
      BookLoan(
        id: id,
        bookId: bookId,
        borrower: borrower,
        lentAt: day(-20),
        dueAt: dueAt,
        returnedAt: returnedAt,
      );

  /// 期限超過・本日・間近・余裕あり・返却済の5件。
  List<BookLoan> sampleLoans() => [
        loan(id: 'l_over', borrower: '田中', dueAt: day(-8)),
        loan(id: 'l_today', borrower: '佐藤', dueAt: day(0)),
        loan(id: 'l_soon', borrower: '鈴木', dueAt: day(3)),
        loan(id: 'l_later', borrower: '高橋', dueAt: day(30)),
        loan(
          id: 'l_returned',
          borrower: '渡辺',
          dueAt: day(5),
          returnedAt: day(-1),
        ),
      ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    required BookLoanRepository repository,
    Future<Map<String, String>> Function()? bookTitleLoader,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LoanManagementScreen(
          repository: repository,
          nowOverride: now,
          bookTitleLoader: bookTitleLoader,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('読込中は ProgressIndicator を出す', (tester) async {
    final completer = Completer<List<BookLoan>>();
    final repository = DelayedLoanRepository(() => completer.future);
    await pumpScreen(tester, repository: repository, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(AppKeys.loanEmpty), findsOneWidget);
  });

  testWidgets('サマリーは BookLoanService.summaryLabel と一致する', (tester) async {
    final loans = sampleLoans();
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(loans);

    await pumpScreen(tester, repository: repository);

    final expected = BookLoanService.summaryLabel(loans, now: now);
    expect(find.text(expected), findsOneWidget);
    // 画面側の独自集計（例: 全件数=5）に化けていないこと
    expect(find.text('貸出中 4冊（期限超過 1）'), findsOneWidget);
    expect(find.textContaining('5冊'), findsNothing);
  });

  testWidgets('すべて: 貸出中も履歴も表示する', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tapKey(tester, AppKeys.loanFilterAll);

    for (final id in ['l_over', 'l_today', 'l_soon', 'l_later', 'l_returned']) {
      expect(find.byKey(AppKeys.loanRow(id)), findsOneWidget, reason: id);
    }
  });

  testWidgets('貸出中チップは返却済を除外する', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tapKey(tester, AppKeys.loanFilterActive);

    expect(find.byKey(AppKeys.loanRow('l_over')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_later')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_returned')), findsNothing);
  });

  testWidgets('履歴チップは返却済のみを表示する', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tapKey(tester, AppKeys.loanFilterReturned);

    expect(find.byKey(AppKeys.loanRow('l_returned')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_over')), findsNothing);
    expect(find.byKey(AppKeys.loanRow('l_today')), findsNothing);
    expect(find.byKey(AppKeys.loanRow('l_later')), findsNothing);
  });

  testWidgets('返却予定間近チップは期限超過と間近を含み余裕あり/履歴を除く', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tapKey(tester, AppKeys.loanFilterDueSoon);

    expect(find.byKey(AppKeys.loanRow('l_over')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_today')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_soon')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_later')), findsNothing);
    expect(find.byKey(AppKeys.loanRow('l_returned')), findsNothing);
  });

  testWidgets('検索は借り手名で絞り込める', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tester.enterText(find.byKey(AppKeys.loanSearchField), '鈴');
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.loanRow('l_soon')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_over')), findsNothing);
    expect(find.byKey(AppKeys.loanRow('l_later')), findsNothing);
  });

  testWidgets('空クエリで全件に戻る', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tester.enterText(find.byKey(AppKeys.loanSearchField), '田中');
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.loanRow('l_over')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_soon')), findsNothing);

    await tester.enterText(find.byKey(AppKeys.loanSearchField), '');
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.loanRow('l_over')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_soon')), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('l_returned')), findsOneWidget);
  });

  testWidgets('検索ヒットなしは空状態を表示する', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tester.enterText(find.byKey(AppKeys.loanSearchField), '存在しない');
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.loanEmpty), findsOneWidget);
  });

  testWidgets('貸出ゼロは空状態を表示しサマリーは貸出中 0冊', (tester) async {
    await pumpScreen(tester, repository: InMemoryBookLoanRepository());

    expect(find.byKey(AppKeys.loanEmpty), findsOneWidget);
    expect(find.text('貸出中 0冊'), findsOneWidget);
  });

  testWidgets('返却ボタンで repository に返却済が永続化される', (tester) async {
    final repository = SharedLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tapKey(tester, AppKeys.loanReturnButton('l_over'));

    expect(repository.saveCount, greaterThan(0));

    // 別インスタンスから読み直して確認する
    final other = SharedLoanRepository(repository.store);
    final persisted = await other.loadLoans();
    final target = persisted.firstWhere((l) => l.id == 'l_over');

    expect(target.isReturned, isTrue);
    expect(target.returnedAt, now);
    // 他の貸出は巻き添えで返却されない
    expect(persisted.firstWhere((l) => l.id == 'l_soon').isReturned, isFalse);
  });

  testWidgets('返却後は再読込され返却ボタンが消える', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    expect(find.byKey(AppKeys.loanReturnButton('l_over')), findsOneWidget);

    await tapKey(tester, AppKeys.loanReturnButton('l_over'));

    expect(find.byKey(AppKeys.loanReturnButton('l_over')), findsNothing);
    // 貸出中フィルタからも消える
    await tapKey(tester, AppKeys.loanFilterActive);
    expect(find.byKey(AppKeys.loanRow('l_over')), findsNothing);
    // 履歴には現れる
    await tapKey(tester, AppKeys.loanFilterReturned);
    expect(find.byKey(AppKeys.loanRow('l_over')), findsOneWidget);
  });

  testWidgets('書名ローダがあれば行に書名を出す', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([loan(id: 'l1', borrower: '田中', dueAt: day(2))]);

    await pumpScreen(
      tester,
      repository: repository,
      bookTitleLoader: () async => {'b1': '宇宙の本'},
    );

    expect(find.textContaining('宇宙の本'), findsOneWidget);
  });

  testWidgets('書名ローダが無ければ書名は出さない', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([loan(id: 'l1', borrower: '田中', dueAt: day(2))]);

    await pumpScreen(tester, repository: repository);

    expect(find.textContaining('宇宙の本'), findsNothing);
    expect(find.textContaining('田中'), findsOneWidget);
  });

  testWidgets('期限ラベルは BookLoanService.dueLabel と一致する', (tester) async {
    final overdue = loan(id: 'l_over', borrower: '田中', dueAt: day(-8));
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([overdue]);

    await pumpScreen(tester, repository: repository);

    expect(
      find.textContaining(BookLoanService.dueLabel(overdue, now: now)),
      findsOneWidget,
    );
    expect(find.textContaining('期限超過 8日'), findsOneWidget);
  });

  testWidgets('返却ボタンは返却済の行には出ない', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans(sampleLoans());

    await pumpScreen(tester, repository: repository);
    await tapKey(tester, AppKeys.loanFilterReturned);

    expect(find.byKey(AppKeys.loanRow('l_returned')), findsOneWidget);
    expect(find.byKey(AppKeys.loanReturnButton('l_returned')), findsNothing);
  });
}
