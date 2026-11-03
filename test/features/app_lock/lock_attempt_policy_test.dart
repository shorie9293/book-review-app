import 'package:book_review_app/core/infrastructure/lock_attempt_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);

  group('LockAttemptPolicy 定数', () {
    test('無料試行5回・30秒起点・上限15分', () {
      expect(LockAttemptPolicy.maxFreeAttempts, 5);
      expect(LockAttemptPolicy.baseLockout, const Duration(seconds: 30));
      expect(LockAttemptPolicy.maxLockout, const Duration(minutes: 15));
    });
  });

  group('lockoutFor', () {
    test('5回未満はロックアウトなし', () {
      for (var n = 0; n < 5; n++) {
        expect(LockAttemptPolicy.lockoutFor(n), Duration.zero, reason: '$n');
      }
    });

    test('5回目は30秒', () {
      expect(
        LockAttemptPolicy.lockoutFor(5),
        const Duration(seconds: 30),
      );
    });

    test('5回ごとに倍増する', () {
      expect(LockAttemptPolicy.lockoutFor(9), const Duration(seconds: 30));
      expect(LockAttemptPolicy.lockoutFor(10), const Duration(seconds: 60));
      expect(LockAttemptPolicy.lockoutFor(15), const Duration(seconds: 120));
      expect(LockAttemptPolicy.lockoutFor(20), const Duration(seconds: 240));
      expect(LockAttemptPolicy.lockoutFor(25), const Duration(seconds: 480));
    });

    test('15分で頭打ち', () {
      expect(LockAttemptPolicy.lockoutFor(30), const Duration(minutes: 15));
      expect(LockAttemptPolicy.lockoutFor(200), const Duration(minutes: 15));
    });
  });

  group('isLockedOut / remainingSeconds / lockoutLabel', () {
    test('lockedUntil が未来ならロックアウト中', () {
      expect(LockAttemptPolicy.isLockedOut(null, now), isFalse);
      expect(
        LockAttemptPolicy.isLockedOut(now.add(const Duration(seconds: 1)), now),
        isTrue,
      );
      expect(
        LockAttemptPolicy.isLockedOut(now.subtract(const Duration(seconds: 1)), now),
        isFalse,
      );
      expect(LockAttemptPolicy.isLockedOut(now, now), isFalse);
    });

    test('残り秒数は切り上げ・過去は0', () {
      expect(LockAttemptPolicy.remainingSeconds(null, now), 0);
      expect(
        LockAttemptPolicy.remainingSeconds(
          now.add(const Duration(milliseconds: 500)),
          now,
        ),
        1,
      );
      expect(
        LockAttemptPolicy.remainingSeconds(
          now.add(const Duration(seconds: 30)),
          now,
        ),
        30,
      );
      expect(
        LockAttemptPolicy.remainingSeconds(
          now.subtract(const Duration(seconds: 1)),
          now,
        ),
        0,
      );
    });

    test('案内文', () {
      expect(
        LockAttemptPolicy.lockoutLabel(30),
        'しばらく待ってから再試行してください（残り30秒）',
      );
    });
  });
}
