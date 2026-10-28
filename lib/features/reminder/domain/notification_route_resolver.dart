import 'dart:convert';

/// 通知 payload が指し示す遷移先。
///
/// 値等価（[==] / [hashCode]）で比較できる。
class ResolvedNotificationRoute {
  /// 遷移先の識別子（対応表のキー）。
  final String route;

  /// 遷移先へ渡す任意の識別子（例：貸出 ID）。無ければ null。
  final String? id;

  /// 遷移先を生成する。
  const ResolvedNotificationRoute({required this.route, this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedNotificationRoute &&
          other.route == route &&
          other.id == id;

  @override
  int get hashCode => Object.hash(route, id);

  @override
  String toString() => 'ResolvedNotificationRoute(route: $route, id: $id)';
}

/// 通知 payload の遷移先として許容する route 名の対応表。
///
/// 通知サービス（payload 生成・解決）と画面側の対応表は
/// 必ずこの定数を共有する。
abstract final class NotificationRoutes {
  /// 返却期限リマインダー → 貸出管理画面。
  static const String loans = 'loans';

  /// 読書リマインダー → 読書時間（読書の刻）画面。
  static const String reading = 'reading';

  /// 解決を許可する全 route。
  static const Set<String> all = <String>{loans, reading};
}

/// 通知 payload（JSON 文字列）と [ResolvedNotificationRoute] の変換。
///
/// payload 形式: `{"route":"loans","id":"任意"}`。
/// 未知 route・null・空・破損はすべて null を返す（安全側）。
abstract final class NotificationRouteResolver {
  /// payload を解決する。許可されない route は null。
  static ResolvedNotificationRoute? resolve(
    String? payload, {
    required Set<String> allowedRoutes,
  }) {
    if (payload == null) return null;
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return null;

    final Object? decoded;
    try {
      decoded = json.decode(trimmed);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final route = decoded['route'];
    if (route is! String) return null;
    final routeName = route.trim();
    if (routeName.isEmpty) return null;
    if (!allowedRoutes.contains(routeName)) return null;

    final rawId = decoded['id'];
    if (rawId != null && rawId is! String) return null;
    final id = rawId is String && rawId.trim().isNotEmpty ? rawId : null;

    return ResolvedNotificationRoute(route: routeName, id: id);
  }

  /// route（と任意の id）から payload を生成する。
  static String buildPayload(String route, {String? id}) {
    return json.encode(<String, dynamic>{
      'route': route,
      if (id != null && id.trim().isNotEmpty) 'id': id,
    });
  }
}
