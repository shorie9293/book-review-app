import 'dart:io';

import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('v2 ハッシュ形式', () {
    test('v2:<iterations>:<salt>:<hash> 形式・反復1200', () {
      final stored = encodePasscodeHash('1234');
      final parts = stored.split(':');
      expect(parts.length, 4);
      expect(stored, startsWith('v2:1200:'));
      expect(parts[2].length, 32); // 16バイト hex
      expect(parts[3].length, 64);
      expect(matchesPasscodeHash(stored, '1234'), isTrue);
      expect(matchesPasscodeHash(stored, '1235'), isFalse);
    });

    test('同一パスコードでもソルトが異なればハッシュは不一致', () {
      final a = encodePasscodeHash('1234');
      final b = encodePasscodeHash('1234');
      expect(a, isNot(equals(b)));
      expect(matchesPasscodeHash(a, '1234'), isTrue);
      expect(matchesPasscodeHash(b, '1234'), isTrue);
      expect(a.split(':')[2], isNot(equals(b.split(':')[2])));
    });

    test('旧形式ハッシュも照合できる（後方互換）', () {
      final legacy = hashPasscode('1234');
      expect(isLegacyPasscodeHash(legacy), isTrue);
      expect(matchesPasscodeHash(legacy, '1234'), isTrue);
      expect(matchesPasscodeHash(legacy, '1235'), isFalse);
    });

    test('壊れた v2 文字列は false', () {
      expect(matchesPasscodeHash('v2:abc:aa:bb', '1234'), isFalse);
      expect(matchesPasscodeHash('v2:0:aa:bb', '1234'), isFalse);
    });
  });

  group('InMemory リポジトリ: v2 保存と試行状態', () {
    test('setPasscode は v2 を保存し、同じパスコードでも毎回ソルトが変わる', () async {
      final repo = InMemoryAppLockRepository();
      await repo.setPasscode('1234');
      final first = repo.getPasscodeHash()!;
      await repo.setPasscode('1234');
      final second = repo.getPasscodeHash()!;
      expect(first, startsWith('v2:1200:'));
      expect(second, startsWith('v2:1200:'));
      expect(first, isNot(equals(second)));
      expect(repo.verifyPasscode('1234'), isTrue);
    });

    test('失敗件数・lockedUntil の往復と resetAttempts', () async {
      final repo = InMemoryAppLockRepository();
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
      expect(repo.getRelockGraceSeconds(), 0);

      await repo.setFailedAttempts(4);
      final until = DateTime(2026, 1, 1, 12, 0, 30);
      await repo.setLockedUntil(until);
      expect(repo.getFailedAttempts(), 4);
      expect(repo.getLockedUntil(), until);

      await repo.setRelockGraceSeconds(60);
      expect(repo.getRelockGraceSeconds(), 60);

      await repo.resetAttempts();
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
    });

    test('負値は ArgumentError', () async {
      final repo = InMemoryAppLockRepository();
      expect(() => repo.setFailedAttempts(-1), throwsArgumentError);
      expect(() => repo.setRelockGraceSeconds(-1), throwsArgumentError);
    });
  });

  group('Hive 実装: 旧形式からの無強制移行', () {
    late Directory tmp;

    setUpAll(() async {
      tmp = await Directory.systemTemp.createTemp('app_lock_hash_v2_test');
      Hive.init(tmp.path);
    });

    tearDownAll(() async {
      await Hive.close();
      await tmp.delete(recursive: true);
    });

    test('旧形式で照合成功すると v2 へ投げっぱなし移行', () async {
      final box = await Hive.openBox<dynamic>('settings');
      await box.clear();
      await box.put('app_lock.passcode_hash', hashPasscode('1234'));
      const repo = HiveAppLockRepository();

      expect(repo.getPasscodeHash(), isNot(startsWith('v2:')));
      expect(repo.verifyPasscode('1234'), isTrue);
      await Future<void>.delayed(Duration.zero);

      final migrated = repo.getPasscodeHash()!;
      expect(migrated, startsWith('v2:'));
      expect(migrated.contains(hashPasscode('1234')), isFalse);
      expect(repo.verifyPasscode('1234'), isTrue);
      expect(repo.verifyPasscode('9999'), isFalse);
    });

    test('誤コードでは移行しない', () async {
      final box = await Hive.openBox<dynamic>('settings');
      await box.clear();
      await box.put('app_lock.passcode_hash', hashPasscode('1234'));
      const repo = HiveAppLockRepository();

      expect(repo.verifyPasscode('0000'), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(repo.getPasscodeHash()!.startsWith('v2:'), isFalse);
    });

    test('試行状態の Hive 往復', () async {
      final box = await Hive.openBox<dynamic>('settings');
      await box.clear();
      const repo = HiveAppLockRepository();
      expect(repo.getRelockGraceSeconds(), 0);
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);

      await repo.setRelockGraceSeconds(300);
      await repo.setFailedAttempts(7);
      final until = DateTime.fromMillisecondsSinceEpoch(1767225600000);
      await repo.setLockedUntil(until);
      expect(repo.getRelockGraceSeconds(), 300);
      expect(repo.getFailedAttempts(), 7);
      expect(repo.getLockedUntil(), until);

      await repo.resetAttempts();
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
    });
  });
}
