import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/reminder/domain/notification_route_resolver.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_service.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_service.dart';
import 'package:book_review_app/features/reminder/presentation/notification_tap_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 静穏時間を一切適用しないガード（通知サービス生成用）。
class _PassthroughGuard implements QuietHoursGuard {
  @override
  Future<DateTime?> adjust(DateTime scheduled) async => scheduled;
}

/// push された経路を記録する監視者。
class _RecordingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

/// 遷移先のダミー画面（route 名と id を表示する）。
Widget _dummyDestination(String? id) => Scaffold(
      body: Center(child: Text('dummy:${id ?? 'none'}')),
    );

void main() {
  group('NotificationTapRouter', () {
    testWidgets('既知 route で 1 回だけ push される', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingObserver();
      final router = NotificationTapRouter(
        navigatorKey: navigatorKey,
        destinations: {NotificationRoutes.loans: _dummyDestination},
      );

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('home')),
      ));

      // 初回 home の push は数えない（以後の push のみ観測）。
      observer.pushed.clear();

      final handled = router.handle(
        const ResolvedNotificationRoute(route: NotificationRoutes.loans),
      );
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(observer.pushed.length, 1);
      expect(observer.pushed.single.settings.name, 'notification:loans');
      expect(find.text('dummy:none'), findsOneWidget);
    });

    testWidgets('id が遷移先へ渡される', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final router = NotificationTapRouter(
        navigatorKey: navigatorKey,
        destinations: {NotificationRoutes.loans: _dummyDestination},
      );

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ));

      router.handle(
        const ResolvedNotificationRoute(
          route: NotificationRoutes.loans,
          id: 'loan-7',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('dummy:loan-7'), findsOneWidget);
    });

    testWidgets('未知 route では push しない', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingObserver();
      final router = NotificationTapRouter(
        navigatorKey: navigatorKey,
        destinations: {NotificationRoutes.loans: _dummyDestination},
      );

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('home')),
      ));
      observer.pushed.clear();

      final handled = router.handle(
        const ResolvedNotificationRoute(route: 'unknown'),
      );
      await tester.pumpAndSettle();

      expect(handled, isFalse);
      expect(observer.pushed, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('Navigator 未構築なら false を返し例外を出さない', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final router = NotificationTapRouter(
        navigatorKey: navigatorKey,
        destinations: {NotificationRoutes.loans: _dummyDestination},
      );

      expect(
        router.handle(
          const ResolvedNotificationRoute(route: NotificationRoutes.loans),
        ),
        isFalse,
      );
    });

    testWidgets('同じ route を 2 回処理すれば 2 回 push される', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingObserver();
      final router = NotificationTapRouter(
        navigatorKey: navigatorKey,
        destinations: {NotificationRoutes.loans: _dummyDestination},
      );

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('home')),
      ));
      observer.pushed.clear();

      router.handle(
        const ResolvedNotificationRoute(route: NotificationRoutes.loans),
      );
      await tester.pumpAndSettle();
      router.handle(
        const ResolvedNotificationRoute(route: NotificationRoutes.loans),
      );
      await tester.pumpAndSettle();

      expect(observer.pushed.length, 2);
    });

    test('allowedRoutes は対応表のキーと一致する', () {
      final router = NotificationTapRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        destinations: {
          NotificationRoutes.loans: _dummyDestination,
          NotificationRoutes.reading: _dummyDestination,
        },
      );

      expect(router.allowedRoutes, unorderedEquals(NotificationRoutes.all));
    });

    test('forApp は resolver の許可 route と一致する対応表を持つ', () {
      final router = NotificationTapRouter.forApp(
        navigatorKey: GlobalKey<NavigatorState>(),
        loanRepository: InMemoryBookLoanRepository(),
      );

      expect(router.allowedRoutes, unorderedEquals(NotificationRoutes.all));
    });
  });

  group('BookNotificationService の pendingRoute', () {
    test('コールバック未接続なら pendingRoute に保持する', () {
      final service = BookNotificationService(guard: _PassthroughGuard());

      service.handleNotificationPayload('{"route":"loans","id":"l-1"}');

      expect(
        service.pendingRoute,
        const ResolvedNotificationRoute(route: 'loans', id: 'l-1'),
      );
    });

    test('consumePendingRoute は 1 度だけ返す', () {
      final service = BookNotificationService(guard: _PassthroughGuard());
      service.handleNotificationPayload('{"route":"reading"}');

      expect(
        service.consumePendingRoute(),
        const ResolvedNotificationRoute(route: 'reading'),
      );
      expect(service.consumePendingRoute(), isNull);
      expect(service.pendingRoute, isNull);
    });

    test('未知 route・破損 payload では pendingRoute を汚さない', () {
      final service = BookNotificationService(guard: _PassthroughGuard());

      service.handleNotificationPayload('{"route":"unknown"}');
      service.handleNotificationPayload('broken');
      service.handleNotificationPayload(null);

      expect(service.pendingRoute, isNull);
    });

    test('コールバック接続時はコールバックへ渡し pending を残さない', () {
      final service = BookNotificationService(guard: _PassthroughGuard());
      final received = <ResolvedNotificationRoute>[];
      service.onRouteSelected = received.add;

      service.handleNotificationPayload('{"route":"loans"}');

      expect(
        received,
        const <ResolvedNotificationRoute>[
          ResolvedNotificationRoute(route: 'loans'),
        ],
      );
      expect(service.pendingRoute, isNull);
    });
  });
}
