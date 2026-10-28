import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:book_review_app/features/reminder/domain/notification_route_resolver.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_service.dart';
import 'package:book_review_app/features/reminder/infrastructure/quiet_hours_guard_wiring.dart';

/// 読書リマインダー用のローカル通知ラッパー。
///
/// プラットフォームチャネル呼出は全て try/catch で包み、
/// 失敗しても例外を投げない（MissingPluginException 対策）。
///
/// 送出時刻は [QuietHoursGuard] を通す（静穏時間中は繰延 or 送出中止）。
/// guard を省略した場合は [QuietHoursGuardWiring.create] が使われるため、
/// 設定画面で保存した静穏時間設定が本番経路へそのまま反映される。
class BookNotificationService {
  BookNotificationService({QuietHoursGuard? guard})
      : _guard = guard ?? QuietHoursGuardWiring.create();

  final QuietHoursGuard _guard;

  static const int _reminderBaseId = 200; // 通知ID = 200 + weekday(1..7)
  static const int _testNotificationId = 999;
  static const String _channelId = 'book_reading';

  /// 返却期限リマインダーの通知ID（単一・毎日繰り返し）。
  static const int _loanDueBaseId = 300;

  /// 返却期限リマインダーの通知チャネル。
  static const String _loanChannelId = 'book_loan';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 通知タップ時に呼ばれる遷移ハンドラ（未接続なら [pendingRoute] に保持）。
  void Function(ResolvedNotificationRoute route)? onRouteSelected;

  /// アプリ全体で共有する遷移ハンドラ（本番の router 接続用）。
  static void Function(ResolvedNotificationRoute route)? _globalRouteHandler;

  /// アプリ全体の保留 route（ハンドラ未接続時に保持）。
  static ResolvedNotificationRoute? _globalPendingRoute;

  ResolvedNotificationRoute? _pendingRoute;

  /// 未処理のタップ遷移先（[consumePendingRoute] で取り出すまで保持）。
  ResolvedNotificationRoute? get pendingRoute => _pendingRoute;

  /// 保留中の遷移先を 1 度だけ取り出す。無ければ null。
  ResolvedNotificationRoute? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// アプリ全体の遷移ハンドラを接続する（保留分は即座に流し込む）。
  static void attachGlobalRouteHandler(
    void Function(ResolvedNotificationRoute route)? handler,
  ) {
    _globalRouteHandler = handler;
    final pending = _globalPendingRoute;
    _globalPendingRoute = null;
    if (pending != null && handler != null) handler(pending);
  }

  /// アプリ全体の保留遷移先を 1 度だけ取り出す。無ければ null。
  static ResolvedNotificationRoute? consumeGlobalPendingRoute() {
    final route = _globalPendingRoute;
    _globalPendingRoute = null;
    return route;
  }

  /// 通知 payload を解決し、接続済みハンドラへ渡す（未接続なら保持）。
  ///
  /// 未知 route・null・空・破損 payload では何もしない。
  void handleNotificationPayload(String? payload) {
    final route = NotificationRouteResolver.resolve(
      payload,
      allowedRoutes: NotificationRoutes.all,
    );
    if (route == null) return;

    final handler = onRouteSelected ?? _globalRouteHandler;
    if (handler != null) {
      _pendingRoute = null;
      _globalPendingRoute = null;
      handler(route);
      return;
    }
    _pendingRoute = route;
    _globalPendingRoute = route;
  }

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
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) =>
            handleNotificationPayload(response.payload),
      );

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
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

      // 通知タップで起動された場合も、通常タップと同じ入口へ流す。
      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp ?? false) {
          handleNotificationPayload(
            launchDetails?.notificationResponse?.payload,
          );
        }
      } catch (e) {
        debugPrint('[BookNotificationService] 起動通知の取得失敗: $e');
      }
    } catch (e) {
      debugPrint('[BookNotificationService] initialize 失敗: $e');
    }
  }

  /// 通知権限を要求する。失敗時は false。
  Future<bool> requestPermission() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
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
        final delivery = await _applyQuietHours(scheduledDate);
        if (delivery == null) {
          // 静穏時間 policy=skip: この曜日は送出しない。
          await _plugin.cancel(id);
          continue;
        }
        await _plugin.zonedSchedule(
          id,
          '📖 読書の刻',
          '積ん読の本を開く刻だ。',
          delivery,
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
          // タップ時に読書時間画面へ遷移させる（route: reading）。
          payload: NotificationRouteResolver.buildPayload(
            NotificationRoutes.reading,
          ),
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

  /// 返却期限リマインダーを毎日 [hour]:[minute] に繰り返し登録する。
  ///
  /// 失敗しても例外は投げない（[scheduleReadingReminder] と同じ流儀）。
  Future<void> scheduleLoanDueReminder({
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final scheduleMode = await _getScheduleMode();
      final delivery =
          await _applyQuietHours(_nextInstanceOfTime(hour, minute));
      if (delivery == null) {
        // 静穏時間 policy=skip: 送出しない（既存登録も解除する）。
        await _plugin.cancel(_loanDueBaseId);
        return;
      }
      await _plugin.zonedSchedule(
        _loanDueBaseId,
        '📚 返却期限のお知らせ',
        body,
        delivery,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _loanChannelId,
            '返却期限',
            channelDescription: '返却期限リマインダーの通知',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        // タップ時に貸出管理画面へ遷移させる（route: loans）。
        payload:
            NotificationRouteResolver.buildPayload(NotificationRoutes.loans),
      );
    } catch (e) {
      debugPrint('[BookNotificationService] scheduleLoanDueReminder 失敗: $e');
    }
  }

  /// 返却期限リマインダー（ID 300）をキャンセルする。
  Future<void> cancelLoanDueReminder() async {
    try {
      await _plugin.cancel(_loanDueBaseId);
    } catch (e) {
      debugPrint('[BookNotificationService] cancelLoanDueReminder 失敗: $e');
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

  /// 静穏時間ガードを通した送出時刻を返す。null は「送出しない」。
  ///
  /// ガード自体の失敗は通知を止めない（従来どおりの時刻へフォールバック）。
  Future<tz.TZDateTime?> _applyQuietHours(tz.TZDateTime scheduled) async {
    try {
      final adjusted = await _guard.adjust(scheduled);
      if (adjusted == null) return null;
      return tz.TZDateTime.from(adjusted, tz.local);
    } catch (e) {
      debugPrint('[BookNotificationService] 静穏時間ガード失敗: $e');
      return scheduled;
    }
  }

  /// 正確アラーム権限があれば exact、なければ inexact へフォールバック。
  Future<AndroidScheduleMode> _getScheduleMode() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
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

  /// 次に来る [hour]:[minute]（今日の時刻が過ぎていれば明日）を返す。
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
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
