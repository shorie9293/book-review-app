import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:book_review_app/core/infrastructure/app_lock_settings_screen.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, AppLockRepository repo) async {
  await tester.pumpWidget(MaterialApp(home: AppLockSettingsScreen(repository: repo)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('不一致パスコードはエラー文言・有効化されない', (tester) async {
    final repo = InMemoryAppLockRepository();
    await _pump(tester, repo);
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.enterText(find.byKey(AppKeys.appLockConfirmField), '5678');
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pumpAndSettle();
    expect(find.text('確認用パスコードと一致しません'), findsOneWidget);
    expect(repo.isEnabled(), isFalse);
  });

  testWidgets('桁不足・非数字はエラー文言', (tester) async {
    final repo = InMemoryAppLockRepository();
    await _pump(tester, repo);
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '123');
    await tester.enterText(find.byKey(AppKeys.appLockConfirmField), '123');
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pumpAndSettle();
    expect(find.text('4桁の数字を入力してください'), findsOneWidget);
    expect(repo.isEnabled(), isFalse);
  });

  testWidgets('一致する4桁で有効化・無効化できる', (tester) async {
    final repo = InMemoryAppLockRepository();
    await _pump(tester, repo);
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.enterText(find.byKey(AppKeys.appLockConfirmField), '1234');
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pumpAndSettle();
    expect(repo.isEnabled(), isTrue);
    expect(find.text('アプリロック有効'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.appLockDisableButton));
    await tester.pumpAndSettle();
    expect(repo.isEnabled(), isFalse);
    expect(repo.getPasscodeHash(), isNull);
    expect(find.byKey(AppKeys.appLockEnableButton), findsOneWidget);
  });

  testWidgets('Scaffold に appLockScreen Key が付く', (tester) async {
    await _pump(tester, InMemoryAppLockRepository());
    expect(find.byKey(AppKeys.appLockScreen), findsOneWidget);
  });
}
