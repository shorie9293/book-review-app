import 'package:book_review_app/core/infrastructure/app_lock_gate.dart';
import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:book_review_app/core/infrastructure/app_lock_service.dart';
import 'package:book_review_app/core/infrastructure/lock_attempt_policy.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  AppLockRepository repo, {
  required DateTime Function() now,
  Duration? grace,
}) {
  return MaterialApp(
    home: AppLockGate(
      repository: repo,
      now: now,
      graceOverride: grace,
      unlockedBuilder: (context) =>
          const Scaffold(body: Text('UNLOCKED_CONTENT')),
    ),
  );
}

Future<void> _lifecycle(WidgetTester tester, AppLifecycleState state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
    (_) {},
  );
  await tester.pumpAndSettle();
}

Future<InMemoryAppLockRepository> _enabledRepo() async {
  final repo = InMemoryAppLockRepository();
  await repo.setPasscode('1234');
  await repo.setMethod(AppLockMethod.passcode);
  await repo.setEnabled(true);
  return repo;
}

Future<void> _unlock(WidgetTester tester) async {
  await tester.enterText(find.byKey(AppKeys.appLockGateField), '1234');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  final start = DateTime(2026, 1, 1, 12);

  testWidgets('inactive -> paused -> resumed で再施錠される（猶予0）', (tester) async {
    final repo = await _enabledRepo();
    var now = start;
    await tester.pumpWidget(_host(repo, now: () => now));
    await tester.pumpAndSettle();
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);

    await _unlock(tester);
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);

    await _lifecycle(tester, AppLifecycleState.inactive);
    await _lifecycle(tester, AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 5));
    await _lifecycle(tester, AppLifecycleState.resumed);

    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
    final field = tester.widget<TextField>(
      find.byKey(AppKeys.appLockGateField),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('猶予内の復帰では解除状態を保つ', (tester) async {
    final repo = await _enabledRepo();
    var now = start;
    await tester.pumpWidget(
      _host(repo, now: () => now, grace: const Duration(seconds: 60)),
    );
    await tester.pumpAndSettle();
    await _unlock(tester);
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);

    await _lifecycle(tester, AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 30));
    await _lifecycle(tester, AppLifecycleState.resumed);

    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
  });

  testWidgets('猶予を超えた復帰は再施錠', (tester) async {
    final repo = await _enabledRepo();
    var now = start;
    await tester.pumpWidget(
      _host(repo, now: () => now, grace: const Duration(seconds: 60)),
    );
    await tester.pumpAndSettle();
    await _unlock(tester);

    await _lifecycle(tester, AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 61));
    await _lifecycle(tester, AppLifecycleState.resumed);

    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
  });

  testWidgets('設定値（repo）の猶予が使われる', (tester) async {
    final repo = await _enabledRepo();
    await repo.setRelockGraceSeconds(30);
    var now = start;
    await tester.pumpWidget(_host(repo, now: () => now));
    await tester.pumpAndSettle();
    await _unlock(tester);

    await _lifecycle(tester, AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 10));
    await _lifecycle(tester, AppLifecycleState.resumed);
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);

    await _lifecycle(tester, AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 1));
    await _lifecycle(tester, AppLifecycleState.resumed);
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
  });

  testWidgets('無効時は復帰してもロックされない', (tester) async {
    final repo = InMemoryAppLockRepository();
    var now = start;
    await tester.pumpWidget(_host(repo, now: () => now));
    await tester.pumpAndSettle();
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);

    await _lifecycle(tester, AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    await _lifecycle(tester, AppLifecycleState.resumed);
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
  });

  testWidgets('ロックアウト中は解除ボタンが無効・案内文を表示', (tester) async {
    final repo = await _enabledRepo();
    final now = start;
    await repo.setFailedAttempts(5);
    await repo.setLockedUntil(now.add(const Duration(seconds: 30)));

    await tester.pumpWidget(_host(repo, now: () => now));
    await tester.pumpAndSettle();
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
    expect(
      find.textContaining(
        LockAttemptPolicy.lockoutLabel(30),
      ),
      findsOneWidget,
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ロック解除'),
    );
    expect(button.onPressed, isNull);

    // 照合自体が走らない（正しいコードでも解除されない）。
    await _unlock(tester);
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
  });

  group('AppLockService 試行制限', () {
    test('5回失敗でロックアウトし、正解でも解除できない', () async {
      final repo = await _enabledRepo();
      var now = start;
      final service = AppLockService(repo, now: () => now);

      for (var i = 0; i < 5; i++) {
        expect(await service.unlock(passcode: '0000'), isFalse);
      }
      expect(repo.getFailedAttempts(), 5);
      expect(service.isLockedOut, isTrue);
      expect(service.lockoutRemainingSeconds, 30);
      expect(await service.unlock(passcode: '1234'), isFalse);

      now = now.add(const Duration(seconds: 30));
      expect(service.isLockedOut, isFalse);
      expect(await service.unlock(passcode: '1234'), isTrue);
      expect(repo.getFailedAttempts(), 0);
      expect(service.isLockedOut, isFalse);
    });

    test('relockGrace の取得・設定', () async {
      final repo = await _enabledRepo();
      final service = AppLockService(repo);
      expect(service.relockGrace, Duration.zero);
      await service.setRelockGrace(const Duration(minutes: 5));
      expect(service.relockGrace, const Duration(minutes: 5));
    });
  });
}
