import 'package:book_review_app/features/reminder/domain/quiet_hours.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('既定値', () {
    test('無効・22:00〜07:00・defer', () {
      final s = QuietHoursSettings.defaults();
      expect(s.enabled, isFalse);
      expect(s.startMinutes, 22 * 60);
      expect(s.endMinutes, 7 * 60);
      expect(s.policy, QuietHoursPolicy.defer);
      expect(s.startLabel, '22:00');
      expect(s.endLabel, '07:00');
      expect(s.label, '22:00〜07:00');
      expect(s.isDisabledRange, isFalse);
    });
  });

  group('不変条件（ArgumentError）', () {
    test('startHour 範囲外', () {
      expect(() => QuietHoursSettings(startHour: 24), throwsArgumentError);
      expect(() => QuietHoursSettings(startHour: -1), throwsArgumentError);
    });

    test('startMinute 範囲外', () {
      expect(() => QuietHoursSettings(startMinute: 60), throwsArgumentError);
    });

    test('endHour 範囲外', () {
      expect(() => QuietHoursSettings(endHour: 24), throwsArgumentError);
    });

    test('endMinute 範囲外', () {
      expect(() => QuietHoursSettings(endMinute: -1), throwsArgumentError);
    });
  });

  group('JSON', () {
    test('toJson → fromJson 往復', () {
      final s = QuietHoursSettings(
        enabled: true,
        startHour: 21,
        startMinute: 30,
        endHour: 6,
        endMinute: 45,
        policy: QuietHoursPolicy.skip,
      );
      expect(QuietHoursSettings.fromJson(s.toJson()), s);
    });

    test('破損 JSON は既定値へフォールバック', () {
      expect(QuietHoursSettings.fromJson(const {}), QuietHoursSettings.defaults());
      expect(
        QuietHoursSettings.fromJson(const {'enabled': 'yes'}),
        QuietHoursSettings.defaults(),
      );
      expect(
        QuietHoursSettings.fromJson(const {
          'enabled': true,
          'startHour': 22,
          'startMinute': 0,
          'endHour': 7,
          'endMinute': 0,
          'policy': 'unknown',
        }),
        QuietHoursSettings.defaults(),
      );
    });

    test('範囲外の値は既定値へフォールバック', () {
      expect(
        QuietHoursSettings.fromJson(const {
          'enabled': true,
          'startHour': 25,
          'startMinute': 0,
          'endHour': 7,
          'endMinute': 0,
          'policy': 'defer',
        }),
        QuietHoursSettings.defaults(),
      );
    });
  });

  group('copyWith / 値等価', () {
    test('copyWith は指定項目のみ変更する', () {
      final base = QuietHoursSettings.defaults();
      final changed = base.copyWith(enabled: true, startHour: 23);
      expect(changed.enabled, isTrue);
      expect(changed.startHour, 23);
      expect(changed.endHour, base.endHour);
      expect(changed.policy, base.policy);
    });

    test('copyWith の範囲外指定は ArgumentError', () {
      expect(
        () => QuietHoursSettings.defaults().copyWith(startMinute: 99),
        throwsArgumentError,
      );
    });

    test('同値は等しく hashCode も一致する', () {
      final a = QuietHoursSettings(enabled: true, startHour: 22);
      final b = QuietHoursSettings(enabled: true, startHour: 22);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('1項目でも違えば不一致', () {
      final a = QuietHoursSettings(enabled: true);
      expect(a == a.copyWith(enabled: false), isFalse);
      expect(a == a.copyWith(policy: QuietHoursPolicy.skip), isFalse);
      expect(a == a.copyWith(endMinute: 5), isFalse);
    });

    test('start == end は isDisabledRange', () {
      expect(
        QuietHoursSettings(startHour: 22, endHour: 22).isDisabledRange,
        isTrue,
      );
    });
  });
}
