import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/reading/domain/reading_stats.dart';

void main() {
  group('ReadingStats', () {
    test('empty は空', () {
      final s = ReadingStats.empty();
      expect(s.isEmpty, isTrue);
      expect(s.totalMinutes, 0);
      expect(s.sessionCount, 0);
      expect(s.bookCount, 0);
      expect(s.activeDays, 0);
    });

    test('空でない場合', () {
      const s = ReadingStats(
        totalMinutes: 120,
        sessionCount: 2,
        bookCount: 2,
        activeDays: 3,
      );
      expect(s.isEmpty, isFalse);
    });

    test('totalLabel 0分', () {
      expect(ReadingStats.empty().totalLabel, '0分');
    });

    test('totalLabel 分のみ', () {
      const s = ReadingStats(
        totalMinutes: 45,
        sessionCount: 1,
        bookCount: 1,
        activeDays: 1,
      );
      expect(s.totalLabel, '45分');
    });

    test('totalLabel 時間と分の混合', () {
      const s = ReadingStats(
        totalMinutes: 750, // 12時間30分
        sessionCount: 10,
        bookCount: 3,
        activeDays: 5,
      );
      expect(s.totalLabel, '12時間30分');
    });

    test('totalLabel ちょうど時間', () {
      const s = ReadingStats(
        totalMinutes: 120,
        sessionCount: 2,
        bookCount: 1,
        activeDays: 2,
      );
      expect(s.totalLabel, '2時間');
    });

    test('averageMinutesPerSession 0除算回避', () {
      expect(ReadingStats.empty().averageMinutesPerSession, 0.0);
    });

    test('averageMinutesPerSession', () {
      const s = ReadingStats(
        totalMinutes: 90,
        sessionCount: 3,
        bookCount: 2,
        activeDays: 2,
      );
      expect(s.averageMinutesPerSession, 30.0);
    });
  });
}
