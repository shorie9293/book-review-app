import 'package:book_review_app/features/reminder/domain/quiet_hours.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_service.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isWithinQuietHours: 日跨ぎ（22:00〜07:00）', () {
    const start = 22 * 60;
    const end = 7 * 60;

    test('開始ちょうどは静穏時間内', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 8, 22, 0),
          start,
          end,
        ),
        isTrue,
      );
    });

    test('深夜は静穏時間内', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 8, 23, 30),
          start,
          end,
        ),
        isTrue,
      );
    });

    test('早朝は静穏時間内', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 9, 3, 0),
          start,
          end,
        ),
        isTrue,
      );
    });

    test('終了ちょうどは静穏時間外（終端は排他）', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 9, 7, 0),
          start,
          end,
        ),
        isFalse,
      );
    });

    test('昼間は静穏時間外', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 9, 12, 0),
          start,
          end,
        ),
        isFalse,
      );
    });
  });

  group('isWithinQuietHours: 通常区間（12:00〜13:00）', () {
    const start = 12 * 60;
    const end = 13 * 60;

    test('区間内は true', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 8, 12, 30),
          start,
          end,
        ),
        isTrue,
      );
    });

    test('開始直前は false', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 8, 11, 59),
          start,
          end,
        ),
        isFalse,
      );
    });

    test('終了ちょうどは false', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 8, 13, 0),
          start,
          end,
        ),
        isFalse,
      );
    });

    test('分単位で判定する（12:00:59 は区間内）', () {
      expect(
        QuietHoursService.isWithinQuietHours(
          DateTime(2026, 10, 8, 12, 0, 59),
          start,
          end,
        ),
        isTrue,
      );
    });
  });

  test('start == end は常に抑止なし', () {
    const m = 22 * 60;
    expect(
      QuietHoursService.isWithinQuietHours(
        DateTime(2026, 10, 8, 22, 0),
        m,
        m,
      ),
      isFalse,
    );
    expect(
      QuietHoursService.isWithinQuietHours(
        DateTime(2026, 10, 8, 9, 15),
        m,
        m,
      ),
      isFalse,
    );
  });

  group('deferUntil', () {
    test('日跨ぎは翌朝の終了時刻へ繰り延べる', () {
      final deferred = QuietHoursService.deferUntil(
        DateTime(2026, 10, 8, 23, 30),
        22 * 60,
        7 * 60,
      );
      expect(deferred, DateTime(2026, 10, 9, 7, 0));
    });

    test('早朝の静穏時間は同日の終了時刻へ繰り延べる', () {
      final deferred = QuietHoursService.deferUntil(
        DateTime(2026, 10, 9, 3, 0),
        22 * 60,
        7 * 60,
      );
      expect(deferred, DateTime(2026, 10, 9, 7, 0));
    });

    test('静穏時間外はそのまま返す', () {
      final now = DateTime(2026, 10, 9, 12, 34);
      expect(QuietHoursService.deferUntil(now, 22 * 60, 7 * 60), now);
    });

    test('通常区間は同日の終了時刻へ繰り延べる', () {
      final deferred = QuietHoursService.deferUntil(
        DateTime(2026, 10, 8, 12, 10),
        12 * 60,
        13 * 60,
      );
      expect(deferred, DateTime(2026, 10, 8, 13, 0));
    });
  });

  group('resolveDelivery', () {
    final deferSettings = QuietHoursSettings(
      enabled: true,
      startHour: 22,
      endHour: 7,
    );

    test('defer: 静穏時間内は翌朝へ', () {
      expect(
        QuietHoursService.resolveDelivery(
          deferSettings,
          DateTime(2026, 10, 8, 23, 0),
        ),
        DateTime(2026, 10, 9, 7, 0),
      );
    });

    test('defer: 静穏時間外はそのまま', () {
      final scheduled = DateTime(2026, 10, 8, 20, 0);
      expect(
        QuietHoursService.resolveDelivery(deferSettings, scheduled),
        scheduled,
      );
    });

    test('skip: 静穏時間内は null（送出しない）', () {
      final skipSettings = deferSettings.copyWith(policy: QuietHoursPolicy.skip);
      expect(
        QuietHoursService.resolveDelivery(
          skipSettings,
          DateTime(2026, 10, 8, 23, 0),
        ),
        isNull,
      );
    });

    test('skip: 静穏時間外は送出する', () {
      final skipSettings = deferSettings.copyWith(policy: QuietHoursPolicy.skip);
      final scheduled = DateTime(2026, 10, 8, 20, 0);
      expect(
        QuietHoursService.resolveDelivery(skipSettings, scheduled),
        scheduled,
      );
    });

    test('無効なら静穏時間内でもそのまま送出する', () {
      final disabled = deferSettings.copyWith(enabled: false);
      final scheduled = DateTime(2026, 10, 8, 23, 0);
      expect(QuietHoursService.resolveDelivery(disabled, scheduled), scheduled);
    });
  });

  group('formatMinutes / anchorAt', () {
    test('0 は 00:00', () {
      expect(QuietHoursService.formatMinutes(0), '00:00');
    });

    test('65 は 01:05', () {
      expect(QuietHoursService.formatMinutes(65), '01:05');
    });

    test('1440 は 00:00 に正規化される', () {
      expect(QuietHoursService.formatMinutes(1440), '00:00');
    });

    test('anchorAt は時・分だけを差し替える', () {
      final anchor = QuietHoursService.anchorAt(
        DateTime(2026, 10, 8, 9, 0),
        23,
        45,
      );
      expect(anchor, DateTime(2026, 10, 8, 23, 45));
    });
  });

  test('QuietHoursPolicy.fromStorageKey: 未知は defer', () {
    expect(QuietHoursPolicy.fromStorageKey('skip'), QuietHoursPolicy.skip);
    expect(QuietHoursPolicy.fromStorageKey('nope'), QuietHoursPolicy.defer);
    expect(QuietHoursPolicy.fromStorageKey(null), QuietHoursPolicy.defer);
  });
}
