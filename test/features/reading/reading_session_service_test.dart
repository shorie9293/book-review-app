import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/domain/reading_session_service.dart';

void main() {
  const service = ReadingSessionService();
  final day = DateTime(2026, 10, 4);

  group('fromInterval', () {
    test('正しい区間から作れる', () {
      final s = service.fromInterval(
        id: 's1',
        bookId: 'b1',
        bookTitle: '本',
        startedAt: DateTime(2026, 10, 4, 9, 0),
        endedAt: DateTime(2026, 10, 4, 10, 30),
      );
      expect(s.durationMinutes, 90);
      expect(s.bookId, 'b1');
    });

    test('終了 <= 開始 は ArgumentError', () {
      expect(
        () => service.fromInterval(
          id: 's1',
          startedAt: day,
          endedAt: day,
        ),
        throwsArgumentError,
      );
      expect(
        () => service.fromInterval(
          id: 's1',
          startedAt: day,
          endedAt: day.subtract(const Duration(minutes: 1)),
        ),
        throwsArgumentError,
      );
    });
  });

  group('elapsedMinutes', () {
    test('経過を分に丸める', () {
      final start = DateTime(2026, 10, 4, 9, 0);
      expect(
        service.elapsedMinutes(start, start.add(const Duration(minutes: 90))),
        90,
      );
      // 90分59秒 → 90分（切り捨て）
      expect(
        service.elapsedMinutes(
          start,
          start.add(
            const Duration(minutes: 90, seconds: 59),
          ),
        ),
        90,
      );
      expect(
        service.elapsedMinutes(
          start,
          start.add(const Duration(minutes: 91)),
        ),
        91,
      );
    });

    test('経過0分未満は0', () {
      final start = DateTime(2026, 10, 4, 9, 0);
      expect(service.elapsedMinutes(start, start), 0);
      expect(
        service.elapsedMinutes(
          start,
          start.subtract(const Duration(minutes: 5)),
        ),
        0,
      );
    });
  });

  group('minutesByDay', () {
    test('日付ごとに合計', () {
      final totals = service.minutesByDay([
        ReadingSession(
          id: 's1',
          startedAt: DateTime(2026, 10, 4, 9),
          durationMinutes: 30,
        ),
        ReadingSession(
          id: 's2',
          startedAt: DateTime(2026, 10, 4, 20),
          durationMinutes: 15,
        ),
        ReadingSession(
          id: 's3',
          startedAt: DateTime(2026, 10, 3, 9),
          durationMinutes: 60,
        ),
      ]);
      expect(totals[DateTime(2026, 10, 4)], 45);
      expect(totals[DateTime(2026, 10, 3)], 60);
      expect(totals.length, 2);
    });

    test('空リスト', () {
      expect(service.minutesByDay(const []), isEmpty);
    });
  });

  group('recentDailyTotals', () {
    test('昇順・セッションの無い日は0', () {
      final totals = service.recentDailyTotals(
        [
          ReadingSession(
            id: 's1',
            startedAt: DateTime(2026, 10, 2, 9),
            durationMinutes: 30,
          ),
          ReadingSession(
            id: 's2',
            startedAt: DateTime(2026, 10, 4, 9),
            durationMinutes: 20,
          ),
        ],
        DateTime(2026, 10, 4, 23),
        days: 4,
      );
      expect(totals.length, 4);
      expect(totals[0].day, DateTime(2026, 10, 1));
      expect(totals[0].minutes, 0);
      expect(totals[1].day, DateTime(2026, 10, 2));
      expect(totals[1].minutes, 30);
      expect(totals[2].minutes, 0);
      expect(totals[3].day, DateTime(2026, 10, 4));
      expect(totals[3].minutes, 20);
    });

    test('日をまたぐセッションは開始日に帰属', () {
      final totals = service.recentDailyTotals(
        [
          ReadingSession(
            id: 's1',
            startedAt: DateTime(2026, 10, 3, 23, 30),
            durationMinutes: 60,
          ),
        ],
        DateTime(2026, 10, 4, 12),
      );
      expect(totals.last.day, DateTime(2026, 10, 4));
      expect(totals.last.minutes, 0);
      // 直近7日なら 10/3 が含まれる
      final week = service.recentDailyTotals(
        [
          ReadingSession(
            id: 's1',
            startedAt: DateTime(2026, 10, 3, 23, 30),
            durationMinutes: 60,
          ),
        ],
        DateTime(2026, 10, 4, 12),
      );
      expect(week.any((t) => t.day == DateTime(2026, 10, 3) && t.minutes == 60),
          isTrue);
    });

    test('days=0 は空', () {
      expect(
        service.recentDailyTotals(
          const [],
          DateTime(2026, 10, 4),
          days: 0,
        ),
        isEmpty,
      );
    });
  });

  group('summarize', () {
    test('空リストで落ちない', () {
      final stats = service.summarize(const []);
      expect(stats.isEmpty, isTrue);
      expect(stats.totalMinutes, 0);
    });

    test('合計・件数', () {
      final stats = service.summarize([
        ReadingSession(
          id: 's1',
          bookId: 'b1',
          startedAt: DateTime(2026, 10, 4, 9),
          durationMinutes: 30,
        ),
        ReadingSession(
          id: 's2',
          bookId: 'b2',
          startedAt: DateTime(2026, 10, 3, 9),
          durationMinutes: 60,
        ),
      ]);
      expect(stats.totalMinutes, 90);
      expect(stats.sessionCount, 2);
    });

    test('bookCount は bookId 非null の異なり数', () {
      final stats = service.summarize([
        ReadingSession(
          id: 's1',
          bookId: 'b1',
          startedAt: DateTime(2026, 10, 4, 9),
          durationMinutes: 30,
        ),
        ReadingSession(
          id: 's2',
          bookId: 'b1',
          startedAt: DateTime(2026, 10, 4, 10),
          durationMinutes: 10,
        ),
        ReadingSession(
          id: 's3',
          bookId: null,
          startedAt: DateTime(2026, 10, 4, 11),
          durationMinutes: 10,
        ),
        ReadingSession(
          id: 's4',
          bookId: 'b2',
          startedAt: DateTime(2026, 10, 4, 12),
          durationMinutes: 10,
        ),
      ]);
      expect(stats.bookCount, 2);
      expect(stats.sessionCount, 4);
    });

    test('activeDays は日付ユニーク数', () {
      final stats = service.summarize([
        ReadingSession(
          id: 's1',
          startedAt: DateTime(2026, 10, 4, 9),
          durationMinutes: 10,
        ),
        ReadingSession(
          id: 's2',
          startedAt: DateTime(2026, 10, 4, 20),
          durationMinutes: 10,
        ),
        ReadingSession(
          id: 's3',
          startedAt: DateTime(2026, 10, 2, 9),
          durationMinutes: 10,
        ),
      ]);
      expect(stats.activeDays, 2);
      expect(stats.totalMinutes, 30);
    });
  });

  group('sortByRecent', () {
    List<ReadingSession> sessions(List<({String id, DateTime at})> specs) => [
          for (final s in specs)
            ReadingSession(
              id: s.id,
              startedAt: s.at,
              durationMinutes: 10,
            ),
        ];

    test('startedAt 降順・同時刻は id 昇順', () {
      final input = sessions([
        (id: 'a', at: DateTime(2026, 10, 1)),
        (id: 'c', at: DateTime(2026, 10, 3)),
        (id: 'b', at: DateTime(2026, 10, 3)),
      ]);
      final sorted = service.sortByRecent(input);
      expect(sorted.map((s) => s.id).toList(), ['b', 'c', 'a']);
    });

    test('入力非破壊', () {
      final input = sessions([
        (id: 'a', at: DateTime(2026, 10, 1)),
        (id: 'b', at: DateTime(2026, 10, 3)),
      ]);
      service.sortByRecent(input);
      expect(input.map((s) => s.id).toList(), ['a', 'b']);
    });
  });

  group('filterByBook', () {
    List<ReadingSession> sessions() => [
          ReadingSession(
            id: 's1',
            bookId: 'b1',
            startedAt: day,
            durationMinutes: 10,
          ),
          ReadingSession(
            id: 's2',
            bookId: 'b2',
            startedAt: day,
            durationMinutes: 10,
          ),
          ReadingSession(
            id: 's3',
            bookId: null,
            startedAt: day,
            durationMinutes: 10,
          ),
        ];

    test('bookId 指定で絞り込み', () {
      final result = service.filterByBook(sessions(), 'b1');
      expect(result.map((s) => s.id).toList(), ['s1']);
    });

    test('null 指定は紐づきなし', () {
      final result = service.filterByBook(sessions(), null);
      expect(result.map((s) => s.id).toList(), ['s3']);
    });
  });

  group('DailyReadingTotal', () {
    test('== / hashCode', () {
      final a = DailyReadingTotal(day: day, minutes: 30);
      final b = DailyReadingTotal(day: day, minutes: 30);
      final c = DailyReadingTotal(day: day, minutes: 45);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a == (null as DailyReadingTotal?), isFalse);
    });
  });
}
