import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知権限の状態。
///
/// Android 13+（targetSdk 33+）では POST_NOTIFICATIONS が実行時権限であり、
/// 明示的に要求しない限り既定で拒否される（＝通知が一度も出ない）。
enum NotificationPermissionStatus {
  /// 許可済み。
  granted,

  /// 拒否された（まだ再要求の余地がある）。
  denied,

  /// 恒久的に拒否された（OS のダイアログはもう出ない＝設定画面へ誘導する）。
  permanentlyDenied,

  /// 権限要求の概念が無いプラットフォーム。
  unsupported,
}

/// 通知権限の要求窓口（薄い抽象）。
///
/// 画面は本インターフェースにのみ依存し、試練ではフェイクを注入する。
abstract class NotificationPermissionRequester {
  /// 権限を確保する。
  ///
  /// - [alreadyAsked] が true の場合は**要求せず**現在の状態のみを返す
  ///   （OS のダイアログを二度出さない）。
  /// - 既に許可済みなら要求しない（[NotificationPermissionStatus.granted]）。
  /// - 例外は内部で握り潰し [NotificationPermissionStatus.denied] を返す。
  Future<NotificationPermissionStatus> ensure({required bool alreadyAsked});

  /// OS のアプリ設定画面（通知許可の切り替え）を開く。失敗しても投げない。
  Future<void> openAppSettings();
}

/// 下位のプラットフォーム抽象（MethodChannel / プラグイン呼出の隔離層）。
///
/// 試練ではこのインターフェースをフェイクに差し替えることで、
/// プラットフォームチャネル無しで「要求が呼ばれた/呼ばれない」を固定できる。
abstract class NotificationPermissionPlatform {
  /// 通知が有効か（Android のみ意味を持つ。非対応なら null）。
  Future<bool?> areNotificationsEnabled();

  /// Android の POST_NOTIFICATIONS を要求する（非対応なら null）。
  Future<bool?> requestNotificationsPermission();

  /// iOS の通知権限を要求する（非対応なら null）。
  Future<bool?> requestIosPermissions();

  /// OS のアプリ設定画面を開く。
  Future<void> openSettings();
}

/// 本番実装。プラグイン／チャネル呼出を [NotificationPermissionPlatform] に委譲する。
class PlatformNotificationPermissionRequester
    implements NotificationPermissionRequester {
  PlatformNotificationPermissionRequester({
    NotificationPermissionPlatform? platform,
  }) : _platform = platform ?? FlutterLocalNotificationsPermissionPlatform();

  final NotificationPermissionPlatform _platform;

  @override
  Future<NotificationPermissionStatus> ensure({
    required bool alreadyAsked,
  }) async {
    try {
      final enabled = await _platform.areNotificationsEnabled();
      if (enabled == true) {
        // 許可済みなら再要求しない。
        return NotificationPermissionStatus.granted;
      }
      if (enabled == null) {
        // Android 実装が無い＝iOS もしくは非対応。
        if (alreadyAsked) return NotificationPermissionStatus.denied;
        final ios = await _platform.requestIosPermissions();
        if (ios == null) return NotificationPermissionStatus.unsupported;
        return ios
            ? NotificationPermissionStatus.granted
            : NotificationPermissionStatus.denied;
      }
      if (alreadyAsked) return NotificationPermissionStatus.denied;
      final granted = await _platform.requestNotificationsPermission();
      // Android は一度拒否すると OS が二度目のダイアログを出さないため、
      // 要求が通らなかった時点で恒久拒否として扱う。
      return granted == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.permanentlyDenied;
    } catch (e) {
      debugPrint('[NotificationPermissionRequester] ensure 失敗: $e');
      return NotificationPermissionStatus.denied;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _platform.openSettings();
    } catch (e) {
      debugPrint('[NotificationPermissionRequester] openAppSettings 失敗: $e');
    }
  }
}

/// flutter_local_notifications を用いた本番プラットフォーム実装。
class FlutterLocalNotificationsPermissionPlatform
    implements NotificationPermissionPlatform {
  FlutterLocalNotificationsPermissionPlatform({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool?> areNotificationsEnabled() async {
    final android = _android;
    if (android == null) return null;
    return android.areNotificationsEnabled();
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    final android = _android;
    if (android == null) return null;
    return android.requestNotificationsPermission();
  }

  @override
  Future<bool?> requestIosPermissions() async {
    final ios = _ios;
    if (ios == null) return null;
    return ios.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  Future<void> openSettings() async {
    // Android のアプリ詳細設定は URL スキームで開けないため、ネイティブ側の
    // MethodChannel 実装（MainActivity.kt）に委譲する。
    await _settingsChannel.invokeMethod<bool>('openAppSettings');
  }

  static const MethodChannel _settingsChannel =
      MethodChannel('com.takamagahara.book_review_app/app_settings');
}
