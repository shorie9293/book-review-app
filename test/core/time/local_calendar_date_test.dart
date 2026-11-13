import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/time/local_calendar_date.dart';

void main() {
  group('normalizeToLocal', () {
    test('ローカル種別はそのまま返す（冪等）', () {
      final dt = DateTime(2026, 11, 1, 0, 5);
      expect(normalizeToLocal(dt), dt);
      expect(normalizeToLocal(normalizeToLocal(dt)), dt);
      expect(normalizeToLocal(dt).isUtc, isFalse);
    });

    test('UTC 種別は同じ瞬間のローカル表現へ変換する（冪等）', () {
      final utc = DateTime.utc(2026, 11, 1, 0, 5);
      final once = normalizeToLocal(utc);

      expect(once.isUtc, isFalse);
      expect(once.isAtSameMomentAs(utc), isTrue);
      expect(normalizeToLocal(once), once);
      expect(normalizeToLocal(utc), once);
    });
  });

  group('localDateOnly', () {
    test('ローカル暦の年月日0時を返す', () {
      final dt = DateTime(2026, 11, 1, 23, 59, 59);
      final date = localDateOnly(dt);

      expect(date, DateTime(2026, 11, 1));
      expect(date.isUtc, isFalse);
      expect(date.hour, 0);
      expect(date.minute, 0);
      expect(date.second, 0);
    });

    test('UTC 種別入力でもローカル暦の日付（0時）を返す', () {
      final utc = DateTime.utc(2026, 3, 15, 12, 30);
      final local = utc.toLocal();

      expect(localDateOnly(utc), DateTime(local.year, local.month, local.day));
      expect(localDateOnly(utc).isUtc, isFalse);
    });

    test('tryLocalDateOnly は null を保存する', () {
      expect(tryLocalDateOnly(null), isNull);
      final utc = DateTime.utc(2026, 3, 15, 12, 30);
      expect(tryLocalDateOnly(utc), localDateOnly(utc));
    });
  });

  group('localYear / localMonth / localDay', () {
    test('ローカル暦の年月日を返す（期待値は toLocal から算出）', () {
      final inputs = <DateTime>[
        DateTime(2026, 1, 1, 0, 0),
        DateTime.utc(2026, 1, 1, 0, 5),
        DateTime.utc(2025, 12, 31, 15, 5),
        DateTime.utc(2026, 7, 15, 23, 45),
      ];
      for (final dt in inputs) {
        final local = dt.toLocal();
        expect(localYear(dt), local.year, reason: '$dt');
        expect(localMonth(dt), local.month, reason: '$dt');
        expect(localDay(dt), local.day, reason: '$dt');
      }
    });
  });

  group('tryParseStoredDateTime は決して throw しない', () {
    test('String 以外は null', () {
      expect(tryParseStoredDateTime(null), isNull);
      expect(tryParseStoredDateTime(123), isNull);
      expect(tryParseStoredDateTime(0), isNull);
      expect(tryParseStoredDateTime(true), isNull);
      expect(tryParseStoredDateTime(<String>[]), isNull);
      expect(tryParseStoredDateTime(<String, Object?>{}), isNull);
    });

    test('空文字・空白のみ・解析不能は null', () {
      for (final raw in <String>['', '   ', 'abc', 'not-a-date']) {
        expect(() => tryParseStoredDateTime(raw), returnsNormally, reason: raw);
        expect(tryParseStoredDateTime(raw), isNull, reason: raw);
      }
    });

    test('存在しない日付・巨大文字列でも throw しない', () {
      final huge = '2026-11-01T00:05:00.000Z${'x' * 100000}';
      for (final raw in <String>['2026-02-30', '2026-02-30T00:00:00Z', '2026-13-01T00:00:00Z', huge]) {
        Object? result;
        expect(
          () => result = tryParseStoredDateTime(raw),
          returnsNormally,
          reason: raw.length > 50 ? '巨大文字列' : raw,
        );
        // 解析された場合でも必ずローカル種別（null か isUtc == false）。
        if (result != null) {
          expect((result! as DateTime).isUtc, isFalse);
        }
      }
    });

    test('Z 付き文字列は解析後にローカル種別へ正規化される', () {
      final parsed = tryParseStoredDateTime('2026-11-01T00:05:00.000Z');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed.isAtSameMomentAs(DateTime.utc(2026, 11, 1, 0, 5)), isTrue);
    });

    test('Z 無し（ローカル保存）文字列もそのままローカル種別', () {
      final parsed = tryParseStoredDateTime('2026-11-01T00:05:00.000');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed, DateTime(2026, 11, 1, 0, 5));
    });
  });

  group("Z 付き瞬間 '2026-11-01T00:05:00.000Z' の暦読み識別", () {
    final parsed = DateTime.parse('2026-11-01T00:05:00.000Z');

    test('parse 結果は UTC 種別、正準関数の結果はローカル種別', () {
      expect(parsed.isUtc, isTrue);
      expect(normalizeToLocal(parsed).isUtc, isFalse);
      expect(localDateOnly(parsed).isUtc, isFalse);
    });

    test('種別差（x.isUtc と localDateOnly(x).isUtc）で識別できる', () {
      // TZ=Asia/Tokyo でも TZ=UTC でも、この瞬間のローカル暦は 11/1 に
      // なりうるため、年月日の値ではなく「種別」で撃つ。
      expect(parsed.isUtc, isNot(localDateOnly(parsed).isUtc));
    });

    test('年月日は常に toLocal 由来', () {
      final local = parsed.toLocal();
      expect(localYear(parsed), local.year);
      expect(localMonth(parsed), local.month);
      expect(localDay(parsed), local.day);
      expect(localDateOnly(parsed), DateTime(local.year, local.month, local.day));
    });
  });

  group('formatLocalDate', () {
    test('ゼロ埋めせずローカル暦の yyyy/M/d を返す', () {
      for (final dt in <DateTime>[
        DateTime(2026, 1, 5),
        DateTime(2026, 11, 30, 23, 59),
        DateTime.utc(2026, 1, 5, 20, 0),
      ]) {
        final local = dt.toLocal();
        expect(formatLocalDate(dt), '${local.year}/${local.month}/${local.day}');
      }
    });

    test('区切り文字を変更できる', () {
      expect(formatLocalDate(DateTime(2026, 1, 5), separator: '-'), '2026-1-5');
    });

    test('既存表示式と同一出力', () {
      final dt = DateTime.utc(2025, 12, 31, 15, 5);
      final local = dt.toLocal();
      expect(formatLocalDate(dt), '${local.year}/${local.month}/${local.day}');
    });
  });

  group('isSameLocalMonth / isSameLocalYear の種別混在', () {
    test('同じローカル年月なら種別混在でも true', () {
      final utc = DateTime.utc(2026, 1, 31, 20);
      final local = utc.toLocal();
      final sameLocalMonth = DateTime(local.year, local.month, 10);

      expect(isSameLocalMonth(utc, sameLocalMonth), isTrue);
      expect(isSameLocalYear(utc, sameLocalMonth), isTrue);
    });

    test('ローカル暦で隣の月・隣の年なら false', () {
      final utc = DateTime.utc(2026, 1, 31, 20);
      final local = utc.toLocal();
      final nextMonth = DateTime(local.year, local.month + 1, 10);
      final nextYear = DateTime(local.year + 1, local.month, 10);

      expect(isSameLocalMonth(utc, nextMonth), isFalse);
      expect(isSameLocalYear(utc, nextYear), isFalse);
    });
  });
}
