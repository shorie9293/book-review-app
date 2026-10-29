import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/lifecycle/domain/day_rollover_detector.dart';

void main() {
  group('DayRolloverDetector', () {
    test('同じローカル暦日なら sameDay を返し lastSeen を更新する', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 8, 15));

      final result = detector.check(DateTime(2026, 10, 29, 23, 59));

      expect(result, DayRolloverResult.sameDay);
      expect(detector.lastSeen, DateTime(2026, 10, 29, 23, 59));
    });

    test('暦日が翌日へ進んだら rolledOver を返し lastSeen を now へ進める', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 50));

      final result = detector.check(DateTime(2026, 10, 30, 0, 5));

      expect(result, DayRolloverResult.rolledOver);
      expect(detector.lastSeen, DateTime(2026, 10, 30, 0, 5));
    });

    test('暦日が巻き戻ったら clockWentBack を返し lastSeen を据え置く', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 30, 6, 0));

      final result = detector.check(DateTime(2026, 10, 29, 22, 0));

      expect(result, DayRolloverResult.clockWentBack);
      expect(detector.lastSeen, DateTime(2026, 10, 30, 6, 0));
    });

    test('翌日跨ぎの後、その日のうちは sameDay を返し続ける', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 21));

      expect(
        detector.check(DateTime(2026, 10, 30, 1)),
        DayRolloverResult.rolledOver,
      );
      expect(
        detector.check(DateTime(2026, 10, 30, 12)),
        DayRolloverResult.sameDay,
      );
      expect(detector.lastSeen, DateTime(2026, 10, 30, 12));
    });

    test('年を跨いでも暦日判定で rolledOver になる', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 12, 31, 23, 59));

      final result = detector.check(DateTime(2027, 1, 1, 0, 1));

      expect(result, DayRolloverResult.rolledOver);
      expect(detector.lastSeen, DateTime(2027, 1, 1, 0, 1));
    });

    test('巻き戻し後の前進は rolledOver として扱う（据え置いた暦日基準）', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 30, 6, 0));
      expect(
        detector.check(DateTime(2026, 10, 29, 22, 0)),
        DayRolloverResult.clockWentBack,
      );

      final result = detector.check(DateTime(2026, 10, 31, 9, 0));

      expect(result, DayRolloverResult.rolledOver);
      expect(detector.lastSeen, DateTime(2026, 10, 31, 9, 0));
    });
  });
}
