import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reminder/data/reading_reminder_repository.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_permission_requester.dart';
import 'package:book_review_app/features/reminder/infrastructure/reading_reminder_scheduler.dart';
import 'package:book_review_app/features/reminder/presentation/reading_reminder_settings_screen.dart';

/// 通知権限の要求導線の試練。
///
/// Android 13+ では POST_NOTIFICATIONS を要求しない限り通知が出ないため、
/// 「要求が呼ばれた/呼ばれない」を画面の振る舞いとして固定する。
class _FakeRequester implements NotificationPermissionRequester {
  _FakeRequester(this.status);

  final NotificationPermissionStatus status;
  int ensureCalls = 0;
  int openSettingsCalls = 0;
  final List<bool> alreadyAskedArgs = <bool>[];

  @override
  Future<NotificationPermissionStatus> ensure({
    required bool alreadyAsked,
  }) async {
    ensureCalls++;
    alreadyAskedArgs.add(alreadyAsked);
    return status;
  }

  @override
  Future<void> openAppSettings() async {
    openSettingsCalls++;
  }
}

class _FakePlatform implements NotificationPermissionPlatform {
  _FakePlatform({
    this.enabled,
    this.androidRequestResult,
    this.iosRequestResult,
    this.throwOnStatus = false,
  });

  final bool? enabled;
  final bool? androidRequestResult;
  final bool? iosRequestResult;
  final bool throwOnStatus;

  int androidRequestCalls = 0;
  int iosRequestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<bool?> areNotificationsEnabled() async {
    if (throwOnStatus) throw StateError('channel failure');
    return enabled;
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    androidRequestCalls++;
    return androidRequestResult;
  }

  @override
  Future<bool?> requestIosPermissions() async {
    iosRequestCalls++;
    return iosRequestResult;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}

class _NoopScheduler implements ReadingReminderScheduler {
  @override
  Future<void> apply(ReadingReminderSettings s) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> sendTestNotification() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(
    WidgetTester tester,
    NotificationPermissionRequester? requester, {
    bool enabled = false,
  }) async {
    final repository = InMemoryReadingReminderRepository(
      ReadingReminderSettings.defaults().copyWith(enabled: enabled),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReadingReminderSettingsScreen(
          repository: repository,
          scheduler: _NoopScheduler(),
          now: () => DateTime(2026, 10, 8, 9, 0),
          permissionRequester: requester,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('画面を開くと権限要求がちょうど1回・alreadyAsked=false で呼ばれる',
      (tester) async {
    final requester = _FakeRequester(NotificationPermissionStatus.granted);
    await pumpScreen(tester, requester);

    expect(requester.ensureCalls, 1);
    expect(requester.alreadyAskedArgs, <bool>[false]);
  });

  testWidgets('許可済み（granted）なら拒否バナーを出さない', (tester) async {
    await pumpScreen(
      tester,
      _FakeRequester(NotificationPermissionStatus.granted),
    );

    expect(find.byKey(AppKeys.readingReminderPermissionBanner), findsNothing);
  });

  testWidgets('リマインダーをONにすると権限要求が追加で呼ばれる', (tester) async {
    final requester = _FakeRequester(NotificationPermissionStatus.granted);
    await pumpScreen(tester, requester);
    expect(requester.ensureCalls, 1);

    await tester.tap(find.byKey(AppKeys.readingReminderEnabledSwitch));
    await tester.pumpAndSettle();

    expect(requester.ensureCalls, 2);
  });

  testWidgets('リマインダーをOFFにしても権限要求は呼ばれない', (tester) async {
    final requester = _FakeRequester(NotificationPermissionStatus.granted);
    await pumpScreen(tester, requester, enabled: true);
    expect(requester.ensureCalls, 1);

    await tester.tap(find.byKey(AppKeys.readingReminderEnabledSwitch));
    await tester.pumpAndSettle();

    expect(requester.ensureCalls, 1);
  });

  testWidgets('拒否（denied）なら恒久バナーが出て「設定を開く」で設定画面へ誘導する',
      (tester) async {
    final requester = _FakeRequester(NotificationPermissionStatus.denied);
    await pumpScreen(tester, requester);

    expect(
      find.byKey(AppKeys.readingReminderPermissionBanner),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(AppKeys.readingReminderPermissionSettingsButton),
    );
    await tester.pumpAndSettle();

    expect(requester.openSettingsCalls, 1);
  });

  testWidgets('恒久拒否（permanentlyDenied）でもバナーが出る', (tester) async {
    await pumpScreen(
      tester,
      _FakeRequester(NotificationPermissionStatus.permanentlyDenied),
    );

    expect(
      find.byKey(AppKeys.readingReminderPermissionBanner),
      findsOneWidget,
    );
  });

  testWidgets('requester 未注入なら要求もバナーも出さない（従来挙動）',
      (tester) async {
    await pumpScreen(tester, null);

    expect(find.byKey(AppKeys.readingReminderPermissionBanner), findsNothing);
    expect(find.byKey(AppKeys.readingReminderEnabledSwitch), findsOneWidget);
  });

  group('PlatformNotificationPermissionRequester', () {
    test('許可済みなら要求せず granted', () async {
      final platform = _FakePlatform(enabled: true, androidRequestResult: false);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.granted,
      );
      expect(platform.androidRequestCalls, 0);
    });

    test('alreadyAsked=true なら要求せず denied', () async {
      final platform = _FakePlatform(enabled: false);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: true),
        NotificationPermissionStatus.denied,
      );
      expect(platform.androidRequestCalls, 0);
    });

    test('要求して許可されれば granted', () async {
      final platform =
          _FakePlatform(enabled: false, androidRequestResult: true);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.granted,
      );
      expect(platform.androidRequestCalls, 1);
    });

    test('要求が拒否されたら permanentlyDenied', () async {
      final platform =
          _FakePlatform(enabled: false, androidRequestResult: false);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.permanentlyDenied,
      );
    });

    test('例外は握って denied', () async {
      final requester = PlatformNotificationPermissionRequester(
        platform: _FakePlatform(throwOnStatus: true),
      );

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.denied,
      );
    });

    test('非対応プラットフォームは unsupported', () async {
      final requester = PlatformNotificationPermissionRequester(
        platform: _FakePlatform(enabled: null, iosRequestResult: null),
      );

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.unsupported,
      );
    });

    test('iOS の要求結果を反映する', () async {
      final platform = _FakePlatform(enabled: null, iosRequestResult: true);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.granted,
      );
      expect(platform.iosRequestCalls, 1);
    });

    test('openAppSettings は例外を投げない', () async {
      final platform = _FakePlatform(enabled: false);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      await requester.openAppSettings();

      expect(platform.openSettingsCalls, 1);
    });
  });
}
