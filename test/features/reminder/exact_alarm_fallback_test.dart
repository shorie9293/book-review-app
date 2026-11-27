// 正確アラーム権限シームの試練（book-review-app）。
//
// 背景: AndroidManifest から USE_EXACT_ALARM を撤去した。
// USE_EXACT_ALARM 宣言下では canScheduleExactNotifications が常に true を返し、
// inexact フォールバック分岐が死んでいた。よって権限照会をシーム化し、
// 「権限なし → inexactAllowWhileIdle」を実 zonedSchedule 呼出で固定する。
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:book_review_app/features/reminder/domain/quiet_hours_service.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_service.dart';

class _MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// 静穏時間を素通しするガード（時刻を変えない）。
class _PassThroughGuard extends QuietHoursGuard {
  @override
  Future<DateTime?> adjust(DateTime scheduled) async => scheduled;
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    registerFallbackValue(tz.TZDateTime.utc(2026, 1, 1));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
  });

  late _MockFlutterLocalNotificationsPlugin plugin;

  setUp(() {
    plugin = _MockFlutterLocalNotificationsPlugin();
    // zonedSchedule / cancel は Future<void> を返すため明示的にスタブする。
    when(
      () => plugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        uiLocalNotificationDateInterpretation:
            any(named: 'uiLocalNotificationDateInterpretation'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    ).thenAnswer((_) async {});
    when(() => plugin.cancel(any())).thenAnswer((_) async {});
  });

  /// 実際に zonedSchedule へ渡された androidScheduleMode を取り出す。
  AndroidScheduleMode capturedScheduleMode() {
    final captured = verify(
      () => plugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        uiLocalNotificationDateInterpretation:
            any(named: 'uiLocalNotificationDateInterpretation'),
        androidScheduleMode: captureAny(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    ).captured;
    return captured.single as AndroidScheduleMode;
  }

  test('シーム=false なら inexactAllowWhileIdle で登録する', () async {
    final service = BookNotificationService(
      plugin: plugin,
      guard: _PassThroughGuard(),
      exactAlarmAllowed: () async => false,
    );

    await service.scheduleReadingReminder(
      hour: 9,
      minute: 0,
      weekdays: const [1],
    );

    expect(capturedScheduleMode(), AndroidScheduleMode.inexactAllowWhileIdle);
    // シームが権限照会の唯一の入口であること（プラグイン直照会しない）。
    verifyNever(
      () => plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>(),
    );
  });

  test('シーム=true なら exactAllowWhileIdle で登録する', () async {
    final service = BookNotificationService(
      plugin: plugin,
      guard: _PassThroughGuard(),
      exactAlarmAllowed: () async => true,
    );

    await service.scheduleReadingReminder(
      hour: 9,
      minute: 0,
      weekdays: const [1],
    );

    expect(capturedScheduleMode(), AndroidScheduleMode.exactAllowWhileIdle);
  });

  test('返却期限リマインダーもシーム=false で inexact になる', () async {
    final service = BookNotificationService(
      plugin: plugin,
      guard: _PassThroughGuard(),
      exactAlarmAllowed: () async => false,
    );

    await service.scheduleLoanDueReminder(
      body: '返却期限が近づいています。',
      hour: 20,
      minute: 0,
    );

    expect(capturedScheduleMode(), AndroidScheduleMode.inexactAllowWhileIdle);
  });

  test('シームが例外を投げたら安全側（inexact）へ倒す', () async {
    final service = BookNotificationService(
      plugin: plugin,
      guard: _PassThroughGuard(),
      exactAlarmAllowed: () async => throw StateError('permission query failed'),
    );

    await service.scheduleReadingReminder(
      hour: 9,
      minute: 0,
      weekdays: const [1],
    );

    expect(capturedScheduleMode(), AndroidScheduleMode.inexactAllowWhileIdle);
  });

  test('シーム未注入なら従来どおりプラグインへ照会する（後方互換）', () async {
    final service = BookNotificationService(
      plugin: plugin,
      guard: _PassThroughGuard(),
    );

    await service.scheduleReadingReminder(
      hour: 9,
      minute: 0,
      weekdays: const [1],
    );

    // プラグイン照会が実際に走り、Android 実装が無いので inexact へ倒れる。
    verify(
      () => plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>(),
    ).called(greaterThanOrEqualTo(1));
    expect(capturedScheduleMode(), AndroidScheduleMode.inexactAllowWhileIdle);
  });
}
