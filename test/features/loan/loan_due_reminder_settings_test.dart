import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoanDueReminderSettings', () {
    test('既定値は無効・9:00・updatedAt null', () {
      final s = LoanDueReminderSettings.defaults();
      expect(s.enabled, isFalse);
      expect(s.hour, 9);
      expect(s.minute, 0);
      expect(s.updatedAt, isNull);
    });

    test('storageKey は loanDueReminder', () {
      expect(LoanDueReminderSettings.storageKey, 'loanDueReminder');
    });

    test('hour の範囲外は ArgumentError', () {
      expect(() => LoanDueReminderSettings(hour: -1), throwsArgumentError);
      expect(() => LoanDueReminderSettings(hour: 24), throwsArgumentError);
    });

    test('minute の範囲外は ArgumentError', () {
      expect(() => LoanDueReminderSettings(minute: -1), throwsArgumentError);
      expect(() => LoanDueReminderSettings(minute: 60), throwsArgumentError);
    });

    test('境界値 0:00 と 23:59 は許容', () {
      expect(LoanDueReminderSettings(hour: 0, minute: 0).hour, 0);
      expect(LoanDueReminderSettings(hour: 23, minute: 59).minute, 59);
    });

    test('toJson / fromJson 往復', () {
      final s = LoanDueReminderSettings(
        enabled: true,
        hour: 7,
        minute: 45,
        updatedAt: DateTime(2026, 10, 21, 9, 30),
      );
      final restored = LoanDueReminderSettings.fromJson(s.toJson());
      expect(restored, s);
    });

    test('toJson は iso8601 文字列で updatedAt を保存する', () {
      final json = LoanDueReminderSettings(
        enabled: true,
        updatedAt: DateTime(2026, 10, 21, 9, 30),
      ).toJson();
      expect(json['enabled'], isTrue);
      expect(json['hour'], 9);
      expect(json['minute'], 0);
      expect(json['updatedAt'], DateTime(2026, 10, 21, 9, 30).toIso8601String());
    });

    test('updatedAt null は JSON で null', () {
      expect(LoanDueReminderSettings().toJson()['updatedAt'], isNull);
      final restored =
          LoanDueReminderSettings.fromJson(LoanDueReminderSettings().toJson());
      expect(restored.updatedAt, isNull);
    });

    test('copyWith は指定項目のみ差し替える', () {
      final base = LoanDueReminderSettings(
        enabled: true,
        hour: 7,
        minute: 15,
        updatedAt: DateTime(2026, 10, 21, 9),
      );
      final copy = base.copyWith(enabled: false, minute: 0);
      expect(copy.enabled, isFalse);
      expect(copy.hour, 7);
      expect(copy.minute, 0);
      expect(copy.updatedAt, base.updatedAt);
      expect(base.enabled, isTrue);
    });

    test('copyWith は範囲外の値で ArgumentError', () {
      final base = LoanDueReminderSettings();
      expect(() => base.copyWith(hour: 24), throwsArgumentError);
      expect(() => base.copyWith(minute: 60), throwsArgumentError);
    });

    test('fromJson: 欠落キーは FormatException', () {
      expect(
        () => LoanDueReminderSettings.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
      expect(
        () => LoanDueReminderSettings.fromJson(<String, dynamic>{
          'enabled': true,
          'hour': 9,
        }),
        throwsFormatException,
      );
    });

    test('fromJson: 型不一致は FormatException', () {
      expect(
        () => LoanDueReminderSettings.fromJson(<String, dynamic>{
          'enabled': 'yes',
          'hour': 9,
          'minute': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => LoanDueReminderSettings.fromJson(<String, dynamic>{
          'enabled': true,
          'hour': '9',
          'minute': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => LoanDueReminderSettings.fromJson(<String, dynamic>{
          'enabled': true,
          'hour': 9,
          'minute': 0,
          'updatedAt': 12345,
        }),
        throwsFormatException,
      );
    });

    test('fromJson: updatedAt が不正文字列なら FormatException', () {
      expect(
        () => LoanDueReminderSettings.fromJson(<String, dynamic>{
          'enabled': true,
          'hour': 9,
          'minute': 0,
          'updatedAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test('fromJson: 範囲外の hour は FormatException', () {
      expect(
        () => LoanDueReminderSettings.fromJson(<String, dynamic>{
          'enabled': true,
          'hour': 24,
          'minute': 0,
        }),
        throwsFormatException,
      );
    });
  });
}
