import 'dart:convert';

import 'package:book_review_app/features/reminder/domain/notification_route_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const allowed = {'loans', 'reading'};

  group('NotificationRoutes', () {
    test('対応表に loans と reading を含む', () {
      expect(NotificationRoutes.all, containsAll(<String>['loans', 'reading']));
    });

    test('定数は対応表と一致する', () {
      expect(NotificationRoutes.loans, 'loans');
      expect(NotificationRoutes.reading, 'reading');
      expect(
        NotificationRoutes.all,
        unorderedEquals(<String>{
          NotificationRoutes.loans,
          NotificationRoutes.reading,
        }),
      );
    });
  });

  group('NotificationRouteResolver.resolve', () {
    test('null は null', () {
      expect(
        NotificationRouteResolver.resolve(null, allowedRoutes: allowed),
        isNull,
      );
    });

    test('空文字は null', () {
      expect(
        NotificationRouteResolver.resolve('', allowedRoutes: allowed),
        isNull,
      );
    });

    test('空白のみは null', () {
      expect(
        NotificationRouteResolver.resolve('   ', allowedRoutes: allowed),
        isNull,
      );
    });

    test('破損 JSON は null', () {
      expect(
        NotificationRouteResolver.resolve('{not json', allowedRoutes: allowed),
        isNull,
      );
    });

    test('JSON 配列は null', () {
      expect(
        NotificationRouteResolver.resolve('["loans"]', allowedRoutes: allowed),
        isNull,
      );
    });

    test('JSON 文字列は null', () {
      expect(
        NotificationRouteResolver.resolve('"loans"', allowedRoutes: allowed),
        isNull,
      );
    });

    test('route キー欠落は null', () {
      expect(
        NotificationRouteResolver.resolve('{"id":"x"}', allowedRoutes: allowed),
        isNull,
      );
    });

    test('route が文字列でなければ null', () {
      expect(
        NotificationRouteResolver.resolve('{"route":1}',
            allowedRoutes: allowed),
        isNull,
      );
    });

    test('route が空文字なら null', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":""}',
          allowedRoutes: allowed,
        ),
        isNull,
      );
    });

    test('未知 route は null', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":"settings"}',
          allowedRoutes: allowed,
        ),
        isNull,
      );
    });

    test('id なしの既知 route を解決する', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"loans"}',
        allowedRoutes: allowed,
      );
      expect(resolved, isNotNull);
      expect(resolved!.route, 'loans');
      expect(resolved.id, isNull);
    });

    test('id 付きの既知 route を解決する', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"loans","id":"loan-1"}',
        allowedRoutes: allowed,
      );
      expect(resolved, isNotNull);
      expect(resolved!.route, 'loans');
      expect(resolved.id, 'loan-1');
    });

    test('id が文字列でなければ null', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":"loans","id":42}',
          allowedRoutes: allowed,
        ),
        isNull,
      );
    });

    test('id が空文字なら null 扱いで route のみ返す', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"loans","id":"  "}',
        allowedRoutes: allowed,
      );
      expect(resolved, isNotNull);
      expect(resolved!.id, isNull);
    });

    test('未知のキーは無視する', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"reading","extra":"v"}',
        allowedRoutes: allowed,
      );
      expect(resolved, isNotNull);
      expect(resolved!.route, 'reading');
    });

    test('前後の空白を含む payload も解決する', () {
      final resolved = NotificationRouteResolver.resolve(
        '  {"route":"reading"}  ',
        allowedRoutes: allowed,
      );
      expect(resolved, isNotNull);
      expect(resolved!.route, 'reading');
    });

    test('allowedRoutes が空なら常に null', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":"loans"}',
          allowedRoutes: const <String>{},
        ),
        isNull,
      );
    });
  });

  group('NotificationRouteResolver.buildPayload', () {
    test('id なしなら route のみの JSON', () {
      final payload = NotificationRouteResolver.buildPayload('loans');
      final decoded = json.decode(payload) as Map<String, dynamic>;
      expect(decoded['route'], 'loans');
      expect(decoded.containsKey('id'), isFalse);
    });

    test('id 付きなら JSON に含める', () {
      final payload =
          NotificationRouteResolver.buildPayload('loans', id: 'loan-9');
      final decoded = json.decode(payload) as Map<String, dynamic>;
      expect(decoded['route'], 'loans');
      expect(decoded['id'], 'loan-9');
    });

    test('buildPayload → resolve の往復で値が保たれる', () {
      final payload =
          NotificationRouteResolver.buildPayload('reading', id: 'book-3');
      final resolved = NotificationRouteResolver.resolve(
        payload,
        allowedRoutes: allowed,
      );
      expect(
        resolved,
        const ResolvedNotificationRoute(route: 'reading', id: 'book-3'),
      );
    });
  });

  group('ResolvedNotificationRoute', () {
    test('同じ値なら等価で hashCode も一致する', () {
      const a = ResolvedNotificationRoute(route: 'loans', id: 'x');
      const b = ResolvedNotificationRoute(route: 'loans', id: 'x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('id が違えば非等価', () {
      const a = ResolvedNotificationRoute(route: 'loans', id: 'x');
      const b = ResolvedNotificationRoute(route: 'loans', id: 'y');
      expect(a, isNot(b));
    });

    test('id の有無が違えば非等価', () {
      const a = ResolvedNotificationRoute(route: 'loans');
      const b = ResolvedNotificationRoute(route: 'loans', id: 'x');
      expect(a, isNot(b));
    });

    test('toString に route が現れる', () {
      const a = ResolvedNotificationRoute(route: 'reading');
      expect(a.toString(), contains('reading'));
    });
  });
}
