import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 読書リマインダー用のローカル通知ラッパー。
///
/// プラットフォームチャネル呼出は全て try/catch で包み、
/// 失敗しても例外を投げない（MissingPluginException 対策）。
class BookNotificationService {
  static const int _reminderBaseId = 200; // 通知ID = 200 + weekday(1..7)
  static const int _testNotificationId = 999;
  static const String _channelId = 'book_reading';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// timezone 初期化＋tz.local 補正＋プラグイン初期化＋チャンネル作成。
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();

      // 端末の実際のタイムゾーンオフセットを取得し、tz.local を補正する
      final deviceOffset = DateTime.now().timeZoneOffset;
      final tzLocalOffset = tz.TZDateTime.now(tz.local).timeZoneOffset;
      if (deviceOffset != tzLocalOffset) {
        final correctTzName = _findTimezoneByOffset(deviceOffset);
        if (correctTzName != null) {
          tz.setLocalLocation(tz.getLocation(correctTzName));
        }
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: android, iOS: darwin);
      await _plugin.initialize(settings);

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            '読書の刻',
            description: '読書リマインダーの通知',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[BookNotificationService] initialize 失敗: $e');
    }
  }

  /// 通知権限を要求する。失敗時は false。
  Future<bool> requestPermission() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        return granted ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[BookNotificationService] requestPermission 失敗: $e');
      return false;
    }
  }

  /// 読書リマインダーを選択曜日それぞれにスケジュールし、
  /// 未選択曜日をキャンセルする。繰り返しは毎週同時刻。
  Future<void> scheduleReadingReminder({
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) async {
    try {
      final scheduleMode = await _getScheduleMode();
      for (var weekday = 1; weekday <= 7; weekday++) {
        final id = _reminderBaseId + weekday;
        if (!weekdays.contains(weekday)) {
          await _plugin.cancel(id);
          continue;
        }
        final scheduledDate = _nextInstanceOfWeekday(weekday, hour, minute);
        await _plugin.zonedSchedule(
          id,
          '📖 読書の刻',
          '積ん読の本を開く刻だ。',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              '読書の刻',
              channelDescription: '読書リマインダーの通知',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (e) {
      debugPrint('[BookNotificationService] scheduleReadingReminder 失敗: $e');
    }
  }

  /// 読書リマインダー（全曜日分）をキャンセルする。
  Future<void> cancelReadingReminder() async {
    try {
      for (var weekday = 1; weekday <= 7; weekday++) {
        await _plugin.cancel(_reminderBaseId + weekday);
      }
    } catch (e) {
      debugPrint('[BookNotificationService] cancelReadingReminder 失敗: $e');
    }
  }

  /// テスト通知を即座に送信する。
  Future<void> sendTestNotification() async {
    try {
      await _plugin.show(
        _testNotificationId,
        '🔔 テスト通知',
        '通知機能は正常に動作しています！',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'book_test',
            'テスト通知',
            channelDescription: '通知機能のテスト用',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('[BookNotificationService] sendTestNotification 失敗: $e');
    }
  }

  /// 正確アラーム権限があれば exact、なければ inexact へフォールバック。
  Future<AndroidScheduleMode> _getScheduleMode() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final canExact = await androidImpl
            .canScheduleExactNotifications()
            .timeout(const Duration(seconds: 2));
        if (canExact ?? false) {
          return AndroidScheduleMode.exactAllowWhileIdle;
        }
      }
    } catch (_) {
      // 権限確認に失敗したら安全側へ
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// 次に来る [weekday]（1=月..7=日）の [hour]:[minute] を返す。
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// 指定されたオフセットに一致する IANA タイムゾーンを探索する。
  String? _findTimezoneByOffset(Duration offset) {
    final preferredZones = [
      'Asia/Tokyo',
      'Asia/Seoul',
      'Asia/Shanghai',
      'Asia/Taipei',
      'Asia/Hong_Kong',
      'Asia/Singapore',
      'Asia/Kolkata',
      'Europe/London',
      'Europe/Berlin',
      'Europe/Paris',
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'Pacific/Auckland',
      'Australia/Sydney',
      'UTC',
    ];

    for (final zoneName in preferredZones) {
      try {
        final location = tz.getLocation(zoneName);
        final now = tz.TZDateTime.now(location);
        if (now.timeZoneOffset == offset) {
          return zoneName;
        }
      } catch (_) {
        // 無効なゾーン名はスキップ
      }
    }

    for (final entry in tz.timeZoneDatabase.locations.entries) {
      try {
        final now = tz.TZDateTime.now(entry.value);
        if (now.timeZoneOffset == offset) {
          return entry.key;
        }
      } catch (_) {
        // 無効なゾーンはスキップ
      }
    }

    return null;
  }
}
