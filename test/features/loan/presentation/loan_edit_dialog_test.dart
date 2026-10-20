import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/features/loan/presentation/loan_edit_dialog.dart';

void main() {
  final lentAt = DateTime.utc(2026, 9, 18, 12).toLocal();

  /// ダイアログを開くホスト画面。[result] に確定結果を保持する。
  Future<void> pumpHost(
    WidgetTester tester, {
    required void Function(BookLoan?) onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('open_dialog'),
                onPressed: () async {
                  final loan = await LoanEditDialog.show(
                    context,
                    bookId: 'b1',
                    lentAt: lentAt,
                  );
                  onResult(loan);
                },
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();
  }

  testWidgets('必須キーが揃っている', (tester) async {
    await pumpHost(tester, onResult: (_) {});

    expect(find.byKey(AppKeys.loanBorrowerField), findsOneWidget);
    expect(find.byKey(AppKeys.loanDueButton), findsOneWidget);
    expect(find.byKey(AppKeys.loanSaveButton), findsOneWidget);
  });

  testWidgets('借り手未入力で確定するとエラーを出し閉じない', (tester) async {
    BookLoan? result;
    var called = false;
    await pumpHost(tester, onResult: (loan) {
      called = true;
      result = loan;
    });

    await tester.tap(find.byKey(AppKeys.loanSaveButton));
    await tester.pumpAndSettle();

    expect(find.text('借り手名を入力してください'), findsOneWidget);
    expect(find.byKey(AppKeys.loanBorrowerField), findsOneWidget);
    expect(called, isFalse);
    expect(result, isNull);
  });

  testWidgets('空白のみの借り手名もエラーになる', (tester) async {
    var called = false;
    await pumpHost(tester, onResult: (_) => called = true);

    await tester.enterText(find.byKey(AppKeys.loanBorrowerField), '    ');
    await tester.tap(find.byKey(AppKeys.loanSaveButton));
    await tester.pumpAndSettle();

    expect(find.text('借り手名を入力してください'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('借り手名を入れて確定すると BookLoan を返す', (tester) async {
    BookLoan? result;
    await pumpHost(tester, onResult: (loan) => result = loan);

    await tester.enterText(find.byKey(AppKeys.loanBorrowerField), '  田中  ');
    await tester.tap(find.byKey(AppKeys.loanSaveButton));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.bookId, 'b1');
    expect(result!.borrower, '田中');
    expect(result!.lentAt, lentAt);
    expect(result!.dueAt, isNull);
    expect(result!.isReturned, isFalse);
    expect(result!.id.trim().isNotEmpty, isTrue);
    // ダイアログは閉じている
    expect(find.byKey(AppKeys.loanBorrowerField), findsNothing);
  });

  testWidgets('返却予定日ボタンで DatePicker が開く', (tester) async {
    await pumpHost(tester, onResult: (_) {});

    await tester.tap(find.byKey(AppKeys.loanDueButton));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byKey(AppKeys.loanDueButton), findsOneWidget);
  });
}
