import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:book_review_app/core/infrastructure/app_lock_service.dart';
import 'package:book_review_app/core/infrastructure/lock_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<InMemoryAppLockRepository> _lockedRepo() async {
  final repo = InMemoryAppLockRepository();
  await repo.setPasscode('1234');
  await repo.setMethod(AppLockMethod.passcode);
  await repo.setEnabled(true);
  return repo;
}

void main() {
  test('ロック無効なら rejected で何も変更しない', () async {
    final repo = InMemoryAppLockRepository();
    var backedUp = false;
    var erased = false;
    final service = LockRecoveryService(
      AppLockService(repo),
      backupExporter: () async => backedUp = true,
      dataEraser: () async => erased = true,
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.outcome, LockRecoveryOutcome.rejected);
    expect(result.isRecovered, isFalse);
    expect(backedUp, isFalse);
    expect(erased, isFalse);
  });

  test('確認語が不一致なら rejected（ロックは維持）', () async {
    final repo = await _lockedRepo();
    var erased = false;
    final service = LockRecoveryService(
      AppLockService(repo),
      backupExporter: () async {},
      dataEraser: () async => erased = true,
    );

    final result = await service.recover(confirmation: 'ちがう');

    expect(result.outcome, LockRecoveryOutcome.rejected);
    expect(repo.isEnabled(), isTrue);
    expect(erased, isFalse);
  });

  test('確認語一致ならバックアップ→解除→初期化の順に実行する', () async {
    final repo = await _lockedRepo();
    final calls = <String>[];
    final service = LockRecoveryService(
      AppLockService(repo),
      backupExporter: () async => calls.add('backup'),
      dataEraser: () async => calls.add('erase'),
    );

    final result = await service.recover(confirmation: ' 初期化 ');

    expect(result.outcome, LockRecoveryOutcome.recovered);
    expect(result.isRecovered, isTrue);
    expect(result.backupFailed, isFalse);
    expect(result.dataWiped, isTrue);
    expect(repo.isEnabled(), isFalse);
    expect(calls, ['backup', 'erase']);
  });

  test('バックアップ失敗でも回復は続行し backupFailed を立てる', () async {
    final repo = await _lockedRepo();
    var erased = false;
    final service = LockRecoveryService(
      AppLockService(repo),
      backupExporter: () async => throw StateError('disk full'),
      dataEraser: () async => erased = true,
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.outcome, LockRecoveryOutcome.recovered);
    expect(result.backupFailed, isTrue);
    expect(repo.isEnabled(), isFalse);
    expect(erased, isTrue);
  });

  test('初期化失敗でもロックは解除される（fail-safe）', () async {
    final repo = await _lockedRepo();
    final service = LockRecoveryService(
      AppLockService(repo),
      backupExporter: () async {},
      dataEraser: () async => throw StateError('erase failed'),
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.outcome, LockRecoveryOutcome.recovered);
    expect(result.dataWiped, isFalse);
    expect(repo.isEnabled(), isFalse);
    expect(repo.verifyPasscode('1234'), isFalse);
  });

  test('バックアップ・初期化が未指定でも解除は成立する', () async {
    final repo = await _lockedRepo();
    final service = LockRecoveryService(AppLockService(repo));

    final result = await service.recover(confirmation: '初期化');

    expect(result.outcome, LockRecoveryOutcome.recovered);
    expect(result.backupFailed, isFalse);
    expect(result.dataWiped, isFalse);
    expect(repo.isEnabled(), isFalse);
  });
}
