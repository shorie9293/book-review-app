import 'package:book_review_app/core/infrastructure/app_lock_gate.dart';
import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:book_review_app/core/infrastructure/app_lock_service.dart';
import 'package:book_review_app/core/infrastructure/lock_recovery_service.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<InMemoryAppLockRepository> _lockedRepo() async {
  final repo = InMemoryAppLockRepository();
  await repo.setPasscode('1234');
  await repo.setMethod(AppLockMethod.passcode);
  await repo.setEnabled(true);
  return repo;
}

Widget _host(
  AppLockRepository repo, {
  LockRecoveryService? recovery,
}) {
  return MaterialApp(
    home: AppLockGate(
      repository: repo,
      recoveryService: recovery,
      unlockedBuilder: (context) =>
          const Scaffold(body: Text('UNLOCKED_CONTENT')),
    ),
  );
}

void main() {
  testWidgets('ロック中は「パスコードをお忘れですか？」が出てダイアログが開く', (tester) async {
    final repo = await _lockedRepo();
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.appLockForgotButton), findsOneWidget);
    expect(find.text('このアプリはロックされています'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.appLockRecoveryConfirmField), findsOneWidget);
    expect(find.byKey(AppKeys.appLockRecoveryConfirmButton), findsOneWidget);
  });

  testWidgets('確認語を入力して実行するとロックが解除され子が表示される', (tester) async {
    final repo = await _lockedRepo();
    var erased = false;
    final recovery = LockRecoveryService(
      AppLockService(repo),
      backupExporter: () async {},
      dataEraser: () async => erased = true,
    );
    await tester.pumpWidget(_host(repo, recovery: recovery));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppKeys.appLockRecoveryConfirmField),
      '初期化',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.appLockRecoveryConfirmButton));
    await tester.pumpAndSettle();

    expect(erased, isTrue);
    expect(repo.isEnabled(), isFalse);
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('確認語が不一致なら実行できずロックは維持される', (tester) async {
    final repo = await _lockedRepo();
    final recovery = LockRecoveryService(
      AppLockService(repo),
      backupExporter: () async {},
      dataEraser: () async {},
    );
    await tester.pumpWidget(_host(repo, recovery: recovery));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppKeys.appLockRecoveryConfirmField),
      'ちがう',
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(AppKeys.appLockRecoveryConfirmButton),
    );
    expect(button.onPressed, isNull);
    expect(repo.isEnabled(), isTrue);
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
  });
}
