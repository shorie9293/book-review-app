import 'package:book_review_app/core/infrastructure/lock_reload_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LockReloadPolicy.graceOptionsSeconds / graceLabel', () {
    test('選択肢は 0/30/60/300 秒', () {
      expect(LockReloadPolicy.graceOptionsSeconds, [0, 30, 60, 300]);
    });

    test('ラベル', () {
      expect(LockReloadPolicy.graceLabel(0), '即時');
      expect(LockReloadPolicy.graceLabel(30), '30秒');
      expect(LockReloadPolicy.graceLabel(60), '1分');
      expect(LockReloadPolicy.graceLabel(300), '5分');
      expect(LockReloadPolicy.graceLabel(45), '45秒');
    });
  });

  group('LockReloadPolicy.shouldRelock', () {
    final base = DateTime(2026, 1, 1, 12);

    test('バックグラウンド記録なしは施錠', () {
      expect(
        LockReloadPolicy.shouldRelock(null, base, Duration.zero),
        isTrue,
      );
      expect(
        LockReloadPolicy.shouldRelock(null, base, const Duration(minutes: 5)),
        isTrue,
      );
    });

    test('猶予0は即時施錠', () {
      expect(
        LockReloadPolicy.shouldRelock(base, base, Duration.zero),
        isTrue,
      );
      expect(
        LockReloadPolicy.shouldRelock(
          base,
          base.add(const Duration(seconds: 1)),
          Duration.zero,
        ),
        isTrue,
      );
    });

    test('猶予内は施錠しない', () {
      expect(
        LockReloadPolicy.shouldRelock(
          base,
          base.add(const Duration(seconds: 29)),
          const Duration(seconds: 30),
        ),
        isFalse,
      );
      expect(
        LockReloadPolicy.shouldRelock(
          base,
          base.add(const Duration(minutes: 4)),
          const Duration(minutes: 5),
        ),
        isFalse,
      );
    });

    test('猶予ちょうど・超過は施錠', () {
      expect(
        LockReloadPolicy.shouldRelock(
          base,
          base.add(const Duration(seconds: 30)),
          const Duration(seconds: 30),
        ),
        isTrue,
      );
      expect(
        LockReloadPolicy.shouldRelock(
          base,
          base.add(const Duration(hours: 1)),
          const Duration(minutes: 5),
        ),
        isTrue,
      );
    });

    test('時計巻き戻しは安全側で施錠', () {
      expect(
        LockReloadPolicy.shouldRelock(
          base,
          base.subtract(const Duration(minutes: 1)),
          const Duration(minutes: 5),
        ),
        isTrue,
      );
    });
  });
}
