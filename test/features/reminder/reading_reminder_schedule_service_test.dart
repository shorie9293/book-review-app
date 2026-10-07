import 'package:book_review_app/features/reminder/domain/reading_reminder_schedule_service.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ReadingReminderScheduleService();

  ReadingReminderSettings settings({
    bool enabled = true,
    int hour = 20,
    int minute = 0,
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
  }) =>
      ReadingReminderSettings(
        enabled: enabled,
        hour: hour,
        minute: minute,
        weekdays: weekdays,
      );

  group('nextOccurrence', () {
    test('無効なら null', () {
      final now = DateTime(2026, 10, 8, 10); // 木曜
      expect(
        service.nextOccurrence(settings(enabled: false), now),
        isNull,
      );
    });

    test('weekdays 空なら null', () {
      final now = DateTime(2026, 10, 8, 10);
      expect(service.nextOccurrence(settings(weekdays: const []), now), isNull);
    });

    test('本日が対象曜日で時刻前なら本日', () {
      final now = DateTime(2026, 10, 8, 10); // 木曜(4)
      final next = service.nextOccurrence(settings(hour: 20), now);
      expect(next, DateTime(2026, 10, 8, 20));
    });

    test('本日が対象曜日でちょうど時刻なら本日', () {
      final now = DateTime(2026, 10, 8, 20, 0);
      final next = service.nextOccurrence(settings(hour: 20), now);
      expect(next, DateTime(2026, 10, 8, 20));
    });

    test('本日が対象曜日で時刻後なら翌日の対象曜日', () {
      final now = DateTime(2026, 10, 8, 21); // 木曜
      final next = service.nextOccurrence(settings(hour: 20), now);
      expect(next, DateTime(2026, 10, 9, 20)); // 金曜（毎日設定）
    });

    test('週跨ぎ: 土のみ設定で木曜なら翌週土曜', () {
      final now = DateTime(2026, 10, 8, 10); // 木曜
      final next = service.nextOccurrence(settings(weekdays: const [6]), now);
      expect(next, DateTime(2026, 10, 10, 20)); // 土曜
    });

    test('本日が対象外なら翌日以降の対象曜日', () {
      final now = DateTime(2026, 10, 8, 10); // 木曜
      final next = service.nextOccurrence(settings(weekdays: const [5]), now);
      expect(next, DateTime(2026, 10, 9, 20)); // 金曜
    });

    test('週跨ぎ: 土日のみ設定で木曜なら土曜', () {
      final now = DateTime(2026, 10, 8, 10); // 木曜
      final next = service.nextOccurrence(
        settings(weekdays: const [6, 7]),
        now,
      );
      expect(next, DateTime(2026, 10, 10, 20)); // 土曜
    });
  });

  group('occursOn', () {
    test('対象曜日なら true', () {
      expect(service.occursOn(settings(weekdays: const [4]), DateTime(2026, 10, 8)), isTrue);
    });

    test('対象外曜日なら false', () {
      expect(service.occursOn(settings(weekdays: const [1]), DateTime(2026, 10, 8)), isFalse);
    });
  });

  group('isReminderDue', () {
    test('時刻到来なら true', () {
      expect(
        service.isReminderDue(settings(hour: 20), DateTime(2026, 10, 8, 20, 30)),
        isTrue,
      );
    });

    test('時刻前なら false', () {
      expect(
        service.isReminderDue(settings(hour: 20), DateTime(2026, 10, 8, 19, 59)),
        isFalse,
      );
    });

    test('対象外曜日なら false', () {
      expect(
        service.isReminderDue(
          settings(weekdays: const [1]),
          DateTime(2026, 10, 8, 21),
        ),
        isFalse,
      );
    });

    test('無効なら false', () {
      expect(
        service.isReminderDue(
          settings(enabled: false),
          DateTime(2026, 10, 8, 21),
        ),
        isFalse,
      );
    });
  });

  group('shouldNotify', () {
    test('期限到来かつ未読書なら true', () {
      expect(
        service.shouldNotify(
          s: settings(hour: 20),
          now: DateTime(2026, 10, 8, 20, 30),
        ),
        isTrue,
      );
    });

    test('同日に読書済みなら false', () {
      expect(
        service.shouldNotify(
          s: settings(hour: 20),
          now: DateTime(2026, 10, 8, 20, 30),
          lastReadAt: DateTime(2026, 10, 8, 12),
        ),
        isFalse,
      );
    });

    test('読書が前日なら true', () {
      expect(
        service.shouldNotify(
          s: settings(hour: 20),
          now: DateTime(2026, 10, 8, 20, 30),
          lastReadAt: DateTime(2026, 10, 7, 22),
        ),
        isTrue,
      );
    });

    test('期限未到来なら false', () {
      expect(
        service.shouldNotify(
          s: settings(hour: 20),
          now: DateTime(2026, 10, 8, 10),
        ),
        isFalse,
      );
    });
  });

  group('weekdayLabel', () {
    test('空 → なし', () {
      expect(service.weekdayLabel(const []), 'なし');
    });

    test('7件 → 毎日', () {
      expect(service.weekdayLabel(const [7, 6, 5, 4, 3, 2, 1]), '毎日');
    });

    test('平日', () {
      expect(service.weekdayLabel(const [1, 2, 3, 4, 5]), '平日');
    });

    test('土日', () {
      expect(service.weekdayLabel(const [6, 7]), '土日');
    });

    test('月・水・金（ソートされる）', () {
      expect(service.weekdayLabel(const [5, 1, 3]), '月・水・金');
    });
  });

  group('timeLabel', () {
    test('ゼロ埋め HH:mm', () {
      expect(service.timeLabel(20, 5), '20:05');
      expect(service.timeLabel(6, 30), '06:30');
      expect(service.timeLabel(0, 0), '00:00');
    });
  });

  group('upcomingOccurrences', () {
    test('count < 1 は ArgumentError', () {
      final now = DateTime(2026, 10, 8, 10);
      expect(
        () => service.upcomingOccurrences(settings(), now, 0),
        throwsArgumentError,
      );
      expect(
        () => service.upcomingOccurrences(settings(), now, -1),
        throwsArgumentError,
      );
    });

    test('昇順に count 件返す', () {
      final now = DateTime(2026, 10, 8, 10); // 木曜
      final list = service.upcomingOccurrences(settings(), now, 3);
      expect(list.length, 3);
      expect(list[0], DateTime(2026, 10, 8, 20));
      expect(list[1], DateTime(2026, 10, 9, 20));
      expect(list[2], DateTime(2026, 10, 10, 20));
      expect(list[0].isBefore(list[1]), isTrue);
      expect(list[1].isBefore(list[2]), isTrue);
    });

    test('全て now より後', () {
      final now = DateTime(2026, 10, 8, 21);
      final list = service.upcomingOccurrences(settings(), now, 2);
      for (final d in list) {
        expect(d.isAfter(now), isTrue);
      }
    });
  });
}
