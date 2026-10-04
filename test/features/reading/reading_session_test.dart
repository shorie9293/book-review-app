import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

void main() {
  group('ReadingSession', () {
    ReadingSession build({
      int durationMinutes = 45,
      DateTime? startedAt,
    }) {
      return ReadingSession(
        id: 's1',
        bookId: 'b1',
        bookTitle: '本',
        startedAt: startedAt ?? DateTime(2026, 10, 4, 9, 0),
        durationMinutes: durationMinutes,
      );
    }

    test('durationMinutes 0以下は ArgumentError', () {
      expect(
        () => ReadingSession(
          id: 's1',
          startedAt: DateTime(2026, 10, 4),
          durationMinutes: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReadingSession(
          id: 's1',
          startedAt: DateTime(2026, 10, 4),
          durationMinutes: -5,
        ),
        throwsArgumentError,
      );
    });

    test('空 id は ArgumentError', () {
      expect(
        () => ReadingSession(
          id: '',
          startedAt: DateTime(2026, 10, 4),
          durationMinutes: 10,
        ),
        throwsArgumentError,
      );
    });

    test('endedAt は startedAt + durationMinutes', () {
      final s = build(durationMinutes: 90);
      expect(s.endedAt, DateTime(2026, 10, 4, 10, 30));
    });

    test('durationHoursRounded は切り捨て', () {
      expect(build(durationMinutes: 119).durationHoursRounded, 1);
      expect(build(durationMinutes: 120).durationHoursRounded, 2);
      expect(build(durationMinutes: 59).durationHoursRounded, 0);
    });

    test('durationLabel 形式', () {
      expect(build(durationMinutes: 90).durationLabel, '1時間30分');
      expect(build(durationMinutes: 60).durationLabel, '1時間');
      expect(build(durationMinutes: 45).durationLabel, '45分');
      expect(build(durationMinutes: 1).durationLabel, '1分');
    });

    test('JSON 往復', () {
      final s = build(durationMinutes: 75);
      final restored = ReadingSession.fromJson(s.toJson());
      expect(restored, s);
      expect(restored.hashCode, s.hashCode);
    });

    test('bookId/bookTitle null を許容し往復', () {
      final s = ReadingSession(
        id: 's2',
        startedAt: DateTime(2026, 10, 4),
        durationMinutes: 30,
      );
      final restored = ReadingSession.fromJson(s.toJson());
      expect(restored.bookId, isNull);
      expect(restored.bookTitle, isNull);
      expect(restored, s);
    });

    test('不正 JSON は FormatException', () {
      expect(
        () => ReadingSession.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
      expect(
        () => ReadingSession.fromJson(const {
          'id': 's1',
          'startedAt': 'not-a-date',
          'durationMinutes': 10,
        }),
        throwsFormatException,
      );
      expect(
        () => ReadingSession.fromJson(const {
          'id': 's1',
          'startedAt': '2026-10-04T09:00:00.000',
          'durationMinutes': 0,
        }),
        throwsFormatException,
      );
    });

    test('copyWith', () {
      final s = build();
      final copied = s.copyWith(durationMinutes: 120, bookId: null);
      expect(copied.id, s.id);
      expect(copied.durationMinutes, 120);
      expect(copied.bookId, isNull);
      expect(copied.startedAt, s.startedAt);
      // 元は不変
      expect(s.durationMinutes, 45);
      expect(s.bookId, 'b1');
    });

    test('== は id とフィールドで比較', () {
      final a = build();
      final b = build();
      expect(a, b);
      expect(a, isNot(build(durationMinutes: 50)));
    });

    test('toString に情報を含む', () {
      expect(build().toString(), contains('ReadingSession'));
    });
  });
}
