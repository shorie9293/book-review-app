import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:book_review_app/core/infrastructure/app_lock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryAppLockRepository repo;
  late AppLockService service;

  setUp(() {
    repo = InMemoryAppLockRepository();
    service = AppLockService(repo);
  });

  group('AppLockService（純ロジック）', () {
    test('初期状態はロック解除', () {
      expect(service.isLocked, isFalse);
    });

    test('無効時は unlock が常に true（fail-open）', () async {
      expect(await service.unlock(), isTrue);
      expect(await service.unlock(passcode: '9999'), isTrue);
      expect(await service.unlock(biometricSucceeded: false), isTrue);
    });

    test('enableWithPasscode: 4桁数字で有効化', () async {
      await service.enableWithPasscode('1234');
      expect(service.isLocked, isTrue);
      expect(repo.getMethod(), AppLockMethod.passcode);
      expect(repo.getPasscodeHash(), isNotNull);
      expect(await service.unlock(passcode: '1234'), isTrue);
      expect(await service.unlock(passcode: '5678'), isFalse);
      expect(await service.unlock(), isFalse);
    });

    test('enableWithPasscode: 4桁以外・非数字は ArgumentError', () async {
      expect(() => service.enableWithPasscode('123'), throwsArgumentError);
      expect(() => service.enableWithPasscode('12345'), throwsArgumentError);
      expect(() => service.enableWithPasscode('12a4'), throwsArgumentError);
      expect(() => service.enableWithPasscode(''), throwsArgumentError);
    });

    test('biometric 方式では biometricSucceeded で判定', () async {
      await repo.setEnabled(true);
      await repo.setMethod(AppLockMethod.biometric);
      await repo.setPasscode('1234');
      expect(await service.unlock(), isFalse);
      expect(await service.unlock(biometricSucceeded: true), isTrue);
    });

    test('none 方式は有効でも素通り', () async {
      await repo.setEnabled(true);
      await repo.setMethod(AppLockMethod.none);
      expect(await service.unlock(), isTrue);
    });

    test('disable で完全解除（hash も消える）', () async {
      await service.enableWithPasscode('1234');
      await service.disable();
      expect(service.isLocked, isFalse);
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.getMethod(), AppLockMethod.none);
      expect(repo.verifyPasscode('1234'), isFalse);
    });
  });

  group('InMemoryAppLockRepository', () {
    test('setPasscode は salt 付き sha256 を保存する', () async {
      await repo.setPasscode('1234');
      expect(repo.getPasscodeHash(),
          isNot(equals('1234')));
      expect(repo.verifyPasscode('1234'), isTrue);
      expect(repo.verifyPasscode('1235'), isFalse);
    });

    test('hash が未設定なら照合は常に false', () async {
      expect(repo.verifyPasscode('1234'), isFalse);
    });

    test('method の保存と復元', () async {
      expect(repo.getMethod(), AppLockMethod.none);
      await repo.setMethod(AppLockMethod.biometric);
      expect(repo.getMethod(), AppLockMethod.biometric);
    });
  });
}
