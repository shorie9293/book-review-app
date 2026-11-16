import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/bookshelf/domain/app_bar_action_plan.dart';

void main() {
  group('AppBarActionPlan: 振り分けの不変条件', () {
    test('全件が収まる幅なら全件直置きし「その他」を出さない', () {
      final plan = AppBarActionPlan.plan(
        actionCount: 11,
        availableWidth: 800,
      );

      expect(plan.inlineCount, 11);
      expect(plan.overflowCount, 0);
      expect(plan.hasOverflow, isFalse);
    });

    test('収まらない幅では「その他」1スロットを空けて残りを畳む', () {
      final plan = AppBarActionPlan.plan(
        actionCount: 11,
        availableWidth: 360,
      );

      // (360-96)/48 = 5 スロット → 直置き4 + その他1。
      expect(plan.inlineCount, 4);
      expect(plan.overflowCount, 7);
      expect(plan.hasOverflow, isTrue);
      expect(plan.inlineCount + plan.overflowCount, 11);
    });

    test('文字倍率でタイトル確保幅が増えると直置きが減る', () {
      final normal = AppBarActionPlan.plan(
        actionCount: 11,
        availableWidth: 360,
        titleReserve: kAppBarTitleReserveBase,
      );
      final scaled = AppBarActionPlan.plan(
        actionCount: 11,
        availableWidth: 360,
        titleReserve: kAppBarTitleReserveBase * 2,
      );

      expect(scaled.inlineCount, lessThan(normal.inlineCount));
      expect(scaled.inlineCount + scaled.overflowCount, 11);
    });

    test('極端に狭くても直置きは最低1件残す（全操作がメニュー化しない）', () {
      final plan = AppBarActionPlan.plan(
        actionCount: 17,
        availableWidth: 120,
      );

      expect(plan.inlineCount, greaterThanOrEqualTo(1));
      expect(plan.inlineCount + plan.overflowCount, 17);
    });

    test('アクションが無ければ 0/0', () {
      final plan = AppBarActionPlan.plan(
        actionCount: 0,
        availableWidth: 360,
      );

      expect(plan.inlineCount, 0);
      expect(plan.overflowCount, 0);
      expect(plan.hasOverflow, isFalse);
    });

    test('幅と件数の全組み合わせで inline+overflow==件数 を保つ', () {
      for (var width = 200.0; width <= 1200; width += 40) {
        for (var count = 0; count <= 20; count++) {
          final plan = AppBarActionPlan.plan(
            actionCount: count,
            availableWidth: width,
          );
          expect(plan.inlineCount + plan.overflowCount, count,
              reason: 'width=$width count=$count');
          expect(plan.inlineCount, greaterThanOrEqualTo(count == 0 ? 0 : 1),
              reason: 'width=$width count=$count');
        }
      }
    });

    test('ちょうど収まる境界では畳まない', () {
      // 96 + 48*5 = 336 にちょうど5件が収まる。
      final plan = AppBarActionPlan.plan(
        actionCount: 5,
        availableWidth: 336,
      );

      expect(plan.inlineCount, 5);
      expect(plan.overflowCount, 0);
    });
  });
}
