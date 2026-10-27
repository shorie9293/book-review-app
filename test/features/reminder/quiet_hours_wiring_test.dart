import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';
import 'package:book_review_app/features/reminder/data/quiet_hours_repository.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_service.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_settings.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_service.dart';
import 'package:book_review_app/features/reminder/infrastructure/quiet_hours_guard_wiring.dart';
import 'package:book_review_app/features/reminder/infrastructure/reading_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// 静穏時間を一切適用しないガード（記録用サービスの素通し用）。
class _PassthroughGuard implements QuietHoursGuard {
  @override
  Future<DateTime?> adjust(DateTime scheduled) async => scheduled;
}

/// 通知の実送出を行わず、渡された時・分だけを記録するサービス。
class _RecordingNotificationService extends BookNotificationService {
  _RecordingNotificationService() : super(guard: _PassthroughGuard());

  final List<String> calls = [];
  int? hour;
  int? minute;
  List<int>? weekdays;

  @override
  Future<void> scheduleReadingReminder({
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) async {
    calls.add('scheduleReadingReminder');
    this.hour = hour;
    this.minute = minute;
    this.weekdays = weekdays;
  }

  @override
  Future<void> cancelReadingReminder() async => calls.add('cancelReadingReminder');

  @override
  Future<void> scheduleLoanDueReminder({
    required String body,
    required int hour,
    required int minute,
  }) async {
    calls.add('scheduleLoanDueReminder');
    this.hour = hour;
    this.minute = minute;
  }

  @override
  Future<void> cancelLoanDueReminder() async => calls.add('cancelLoanDueReminder');
}

void main() {
  final now = DateTime(2026, 10, 8, 9, 0);

  tearDown(QuietHoursGuardWiring.reset);

  group('QuietHoursGuardWiring', () {
    test('差し替え無し（Hive 未初期化）でも既定値で素通しする', () async {
      final guard = QuietHoursGuardWiring.create();
      final scheduled = DateTime(2026, 10, 8, 23, 0);
      expect(await guard.adjust(scheduled), scheduled);
    });

    test('repositoryFactory の差し替えが既定ガードへ反映される', () async {
      QuietHoursGuardWiring.repositoryFactory = () =>
          InMemoryQuietHoursRepository(QuietHoursSettings(enabled: true));
      final guard = QuietHoursGuardWiring.create();
      expect(
        await guard.adjust(DateTime(2026, 10, 8, 23, 0)),
        DateTime(2026, 10, 9, 7, 0),
      );
    });

    test('reset で差し替えが戻る', () async {
      QuietHoursGuardWiring.repositoryFactory = () => InMemoryQuietHoursRepository(
            QuietHoursSettings(enabled: true, policy: QuietHoursPolicy.skip),
          );
      QuietHoursGuardWiring.reset();
      final guard = QuietHoursGuardWiring.create();
      final scheduled = DateTime(2026, 10, 8, 23, 0);
      expect(await guard.adjust(scheduled), scheduled);
    });
  });

  group('読書リマインダーの静穏時間ガード', () {
    ReadingReminderSettings settingsAt(int hour) => ReadingReminderSettings(
          enabled: true,
          hour: hour,
          weekdays: const [1, 3],
        );

    test('defer: 静穏時間内の時刻は翌朝の終了時刻へ繰り延べる', () async {
      final service = _RecordingNotificationService();
      final scheduler = NotificationServiceReadingReminderScheduler(
        service: service,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(QuietHoursSettings(enabled: true)),
        ),
        now: () => now,
      );

      await scheduler.apply(settingsAt(23));

      expect(service.hour, 7);
      expect(service.minute, 0);
      expect(service.weekdays, [1, 3]);
    });

    test('skip: 静穏時間内なら登録せず解除する', () async {
      final service = _RecordingNotificationService();
      final scheduler = NotificationServiceReadingReminderScheduler(
        service: service,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(
            QuietHoursSettings(enabled: true, policy: QuietHoursPolicy.skip),
          ),
        ),
        now: () => now,
      );

      await scheduler.apply(settingsAt(23));

      expect(service.calls, ['cancelReadingReminder']);
      expect(service.hour, isNull);
    });

    test('静穏時間外はそのままの時刻で登録する', () async {
      final service = _RecordingNotificationService();
      final scheduler = NotificationServiceReadingReminderScheduler(
        service: service,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(QuietHoursSettings(enabled: true)),
        ),
        now: () => now,
      );

      await scheduler.apply(settingsAt(20));

      expect(service.hour, 20);
      expect(service.minute, 0);
    });

    test('無効設定は従来通り登録する', () async {
      final service = _RecordingNotificationService();
      final scheduler = NotificationServiceReadingReminderScheduler(
        service: service,
        now: () => now,
      );

      await scheduler.apply(settingsAt(23));

      expect(service.hour, 23);
    });

    test('リマインダー無効なら解除する', () async {
      final service = _RecordingNotificationService();
      final scheduler = NotificationServiceReadingReminderScheduler(
        service: service,
        now: () => now,
      );

      await scheduler.apply(
        ReadingReminderSettings(enabled: false, weekdays: const [1]),
      );

      expect(service.calls, ['cancelReadingReminder']);
    });
  });

  group('返却期限リマインダーの静穏時間ガード', () {
    test('defer: 23時は翌朝7時へ繰り延べる', () async {
      final service = _RecordingNotificationService();
      final scheduler = NotificationServiceLoanDueReminderScheduler(
        service: service,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(QuietHoursSettings(enabled: true)),
        ),
        now: () => now,
      );

      await scheduler.schedule(body: '返却期限です', hour: 23, minute: 0);

      expect(service.calls, ['scheduleLoanDueReminder']);
      expect(service.hour, 7);
      expect(service.minute, 0);
    });

    test('skip: 静穏時間内なら登録せず解除する', () async {
      final service = _RecordingNotificationService();
      final scheduler = NotificationServiceLoanDueReminderScheduler(
        service: service,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(
            QuietHoursSettings(enabled: true, policy: QuietHoursPolicy.skip),
          ),
        ),
        now: () => now,
      );

      await scheduler.schedule(body: '返却期限です', hour: 23, minute: 0);

      expect(service.calls, ['cancelLoanDueReminder']);
    });

    test('静穏時間外はそのまま登録する', () async {
      final service = _RecordingNotificationService();
      final scheduler = NotificationServiceLoanDueReminderScheduler(
        service: service,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(QuietHoursSettings(enabled: true)),
        ),
        now: () => now,
      );

      await scheduler.schedule(body: '返却期限です', hour: 8, minute: 30);

      expect(service.hour, 8);
      expect(service.minute, 30);
    });
  });
}
