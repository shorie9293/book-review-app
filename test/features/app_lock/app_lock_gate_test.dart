import 'package:book_review_app/core/infrastructure/app_lock_gate.dart';
import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(WidgetTester tester, AppLockRepository repo) {
  return MaterialApp(
    home: AppLockGate(
      repository: repo,
      unlockedBuilder: (context) =>
          const Scaffold(body: Text('UNLOCKED_CONTENT')),
    ),
  );
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(AppKeys.appLockGateField), code);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('無効時は子が表示される（素通り）', (tester) async {
    final repo = InMemoryAppLockRepository();
    await tester.pumpWidget(_host(tester, repo));
    await tester.pumpAndSettle();
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
    expect(find.byKey(AppKeys.appLockGateField), findsNothing);
  });

  testWidgets('有効時は子が隠れ、誤コードでエラー・正コードで解除', (tester) async {
    final repo = InMemoryAppLockRepository();
    await repo.setPasscode('1234');
    await repo.setMethod(AppLockMethod.passcode);
    await repo.setEnabled(true);

    await tester.pumpWidget(_host(tester, repo));
    await tester.pumpAndSettle();
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
    expect(find.byKey(AppKeys.appLockGateField), findsOneWidget);

    // 誤コード → エラー表示・ロック継続
    await _enterCode(tester, '9999');
    expect(find.text('パスコードが正しくありません'), findsOneWidget);
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);

    // 正コード → 解除
    await _enterCode(tester, '1234');
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
  });
}
