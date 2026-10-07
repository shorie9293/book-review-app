import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingReminderSettings コンストラクタ検証', () {
    test('hour が範囲外なら ArgumentError', () {
      expect(() => ReadingReminderSettings(hour: -1), throwsArgumentError);
      expect(() => ReadingReminderSettings(hour: 24), throwsArgumentError);
    });

    test('minute が範囲外なら ArgumentError', () {
      expect(() => ReadingReminderSettings(minute: -1), throwsArgumentError);
      expect(() => ReadingReminderSettings(minute: 60), throwsArgumentError);
    });

    test('weekdays が 1-7 の範囲外なら ArgumentError', () {
      expect(
        () => ReadingReminderSettings(weekdays: const [0]),
        throwsArgumentError,
      );
      expect(
        () => ReadingReminderSettings(weekdays: const [8]),
        throwsArgumentError,
      );
    });

    test('正常値で生成できる', () {
      final s = ReadingReminderSettings(
        enabled: true,
        hour: 20,
        minute: 30,
        weekdays: const [1, 3],
      );
      expect(s.enabled, isTrue);
      expect(s.hour, 20);
      expect(s.minute, 30);
      expect(s.weekdays, [1, 3]);
    });
  });

  group('defaults', () {
    test('無効・20:00・全7日', () {
      final s = ReadingReminderSettings.defaults();
      expect(s.enabled, isFalse);
      expect(s.hour, 20);
      expect(s.minute, 0);
      expect(s.weekdays, [1, 2, 3, 4, 5, 6, 7]);
      expect(s.isDaily, isTrue);
    });
  });

  group('isDaily', () {
    test('7件なら true', () {
      expect(
        ReadingReminderSettings(weekdays: [1, 2, 3, 4, 5, 6, 7]).isDaily,
        isTrue,
      );
    });

    test('7件未満なら false', () {
      expect(ReadingReminderSettings(weekdays: [1]).isDaily, isFalse);
    });
  });

  group('copyWith', () {
    test('指定フィールドのみ変更', () {
      final base = ReadingReminderSettings.defaults();
      final copied = base.copyWith(enabled: true, hour: 21);
      expect(copied.enabled, isTrue);
      expect(copied.hour, 21);
      expect(copied.minute, 0);
      expect(copied.weekdays, base.weekdays);
      expect(identical(copied, base), isFalse);
    });

    test('updatedAt も変更できる', () {
      final t = DateTime(2026, 10, 8, 12);
      final copied = ReadingReminderSettings.defaults().copyWith(updatedAt: t);
      expect(copied.updatedAt, t);
    });
  });

  group('JSON 往復', () {
    test('toJson → fromJson で復元できる', () {
      final s = ReadingReminderSettings(
        enabled: true,
        hour: 7,
        minute: 15,
        weekdays: const [2, 4, 6],
        updatedAt: DateTime(2026, 10, 8, 9, 0),
      );
      final restored = ReadingReminderSettings.fromJson(s.toJson());
      expect(restored, s);
      expect(restored.updatedAt, s.updatedAt);
    });

    test('updatedAt null の往復', () {
      final s = ReadingReminderSettings.defaults();
      final restored = ReadingReminderSettings.fromJson(s.toJson());
      expect(restored, s);
      expect(restored.updatedAt, isNull);
    });
  });

  group('fromJson FormatException', () {
    test('欠落キー', () {
      expect(
        () => ReadingReminderSettings.fromJson({'enabled': true}),
        throwsFormatException,
      );
    });

    test('型不一致 enabled', () {
      expect(
        () => ReadingReminderSettings.fromJson({
          'enabled': 'yes',
          'hour': 20,
          'minute': 0,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
    });

    test('型不一致 hour', () {
      expect(
        () => ReadingReminderSettings.fromJson({
          'enabled': true,
          'hour': '20',
          'minute': 0,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
    });

    test('weekdays の要素型不一致', () {
      expect(
        () => ReadingReminderSettings.fromJson({
          'enabled': true,
          'hour': 20,
          'minute': 0,
          'weekdays': ['1'],
        }),
        throwsFormatException,
      );
    });

    test('範囲外の値は FormatException へ変換', () {
      expect(
        () => ReadingReminderSettings.fromJson({
          'enabled': true,
          'hour': 25,
          'minute': 0,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
    });
  });

  group('等価性', () {
    test('同値なら == true・hashCode 同一', () {
      final a = ReadingReminderSettings(weekdays: [1, 2, 3]);
      final b = ReadingReminderSettings(weekdays: [1, 2, 3]);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('weekdays が異なれば false', () {
      final a = ReadingReminderSettings(weekdays: [1, 2, 3]);
      final b = ReadingReminderSettings(weekdays: [1, 2, 4]);
      expect(a == b, isFalse);
    });
  });
}
