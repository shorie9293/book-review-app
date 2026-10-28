import 'package:flutter/material.dart';

import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';
import 'package:book_review_app/features/loan/presentation/loan_management_screen.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';
import 'package:book_review_app/features/reminder/domain/notification_route_resolver.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';

/// 通知タップ → 該当画面遷移の薄い router。
///
/// payload の解決は [NotificationRouteResolver] に委ね、本クラスは
/// 「許可された route を Navigator へ push する」ことだけを行う。
/// 未知 route・Navigator 未構築では何もしない（false を返す）。
class NotificationTapRouter {
  /// [navigatorKey] と遷移先の対応表から router を生成する。
  ///
  /// [destinations] のキーが許可 route となる（[allowedRoutes]）。
  NotificationTapRouter({
    required this.navigatorKey,
    required Map<String, Widget Function(String? id)> destinations,
  }) : _destinations = Map<String, Widget Function(String? id)>.unmodifiable(
          destinations,
        );

  /// 本番（MaterialApp）用の対応表を組み立てる。
  ///
  /// 通知 payload の route 名と実画面の対応：
  /// - [NotificationRoutes.loans]   → 貸出管理画面
  /// - [NotificationRoutes.reading] → 読書時間（読書の刻）画面
  factory NotificationTapRouter.forApp({
    required GlobalKey<NavigatorState> navigatorKey,
    required BookLoanRepository loanRepository,
    ReadingSessionRepository? readingSessionRepository,
  }) {
    final sessionRepository =
        readingSessionRepository ?? const HiveReadingSessionRepository();
    return NotificationTapRouter(
      navigatorKey: navigatorKey,
      destinations: <String, Widget Function(String? id)>{
        NotificationRoutes.loans: (id) => LoanManagementScreen(
              repository: loanRepository,
              reminderRepository: HiveLoanDueReminderRepository(),
              reminderScheduler: NotificationServiceLoanDueReminderScheduler(),
            ),
        NotificationRoutes.reading: (id) => ReadingSessionScreen(
              repository: sessionRepository,
            ),
      },
    );
  }

  /// 遷移に用いる Navigator の鍵（MaterialApp と共有する）。
  final GlobalKey<NavigatorState> navigatorKey;

  final Map<String, Widget Function(String? id)> _destinations;

  /// 遷移を許可する route（対応表のキー）。
  Set<String> get allowedRoutes => _destinations.keys.toSet();

  /// 解決済み route へ遷移する。遷移したら true。
  bool handle(ResolvedNotificationRoute route) {
    final destination = _destinations[route.route];
    if (destination == null) return false;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'notification:${route.route}'),
        builder: (_) => destination(route.id),
      ),
    );
    return true;
  }

  /// payload を解決して遷移する。解決できなければ false。
  bool handlePayload(String? payload) {
    final route = NotificationRouteResolver.resolve(
      payload,
      allowedRoutes: allowedRoutes,
    );
    if (route == null) return false;
    return handle(route);
  }
}
