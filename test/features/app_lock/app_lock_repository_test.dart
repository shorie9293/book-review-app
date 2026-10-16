import 'dart:io';

import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('app_lock_hive_test');
    Hive.init(tmp.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  group('HiveAppLockRepository', () {
    late HiveAppLockRepository repo;

    setUp(() async {
      final box = await Hive.openBox<dynamic>('settings');
      await box.clear();
      repo = const HiveAppLockRepository();
    });

    test('初期状態は無効・none・hashなし', () {
      expect(repo.isEnabled(), isFalse);
      expect(repo.getMethod(), AppLockMethod.none);
      expect(repo.getPasscodeHash(), isNull);
    });

    test('パスコード保存・照合（salt 付きハッシュ・定数時間比較）', () async {
      await repo.setPasscode('1234');
      final hash = repo.getPasscodeHash()!;
      expect(hash, isNot('1234'));
      expect(hash.length, 64);
      expect(repo.verifyPasscode('1234'), isTrue);
      expect(repo.verifyPasscode('1235'), isFalse);
      expect(repo.verifyPasscode(''), isFalse);
    });

    test('clearPasscode で照合不可になる', () async {
      await repo.setPasscode('9999');
      await repo.clearPasscode();
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.verifyPasscode('9999'), isFalse);
    });

    test('enabled / method の永続化', () async {
      await repo.setEnabled(true);
      await repo.setMethod(AppLockMethod.passcode);
      expect(repo.isEnabled(), isTrue);
      expect(repo.getMethod(), AppLockMethod.passcode);
      await repo.setEnabled(false);
      await repo.setMethod(AppLockMethod.none);
      expect(repo.isEnabled(), isFalse);
      expect(repo.getMethod(), AppLockMethod.none);
    });
  });

  group('constantTimeEquals / hashPasscode', () {
    test('同じ文字列は true・異なる文字列は false', () {
      expect(constantTimeEquals('abc', 'abc'), isTrue);
      expect(constantTimeEquals('abc', 'abd'), isFalse);
      expect(constantTimeEquals('abc', 'abcd'), isFalse);
    });

    test('salt が反映される', () {
      expect(hashPasscode('1234'), equals(hashPasscode('1234')));
      expect(hashPasscode('1234'), isNot(equals(hashPasscode('4321'))));
    });
  });
}
