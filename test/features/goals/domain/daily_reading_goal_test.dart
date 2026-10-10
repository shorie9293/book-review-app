import 'package:book_review_app/features/goals/domain/daily_reading_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyReadingGoal モデル', () {
    test('デフォルトは未設定', () {
      const goal = DailyReadingGoal();
      expect(goal.targetMinutes, 0);
      expect(goal.updatedAt, '');
      expect(goal.isSet, isFalse);
    });

    test('empty コンストラクタは未設定', () {
      const goal = DailyReadingGoal.empty();
      expect(goal.isSet, isFalse);
    });

    test('isSet は targetMinutes>0 で true', () {
      const goal = DailyReadingGoal(targetMinutes: 30);
      expect(goal.isSet, isTrue);
    });

    test('copyWith は指定フィールドのみ差し替え', () {
      const goal = DailyReadingGoal(targetMinutes: 10, updatedAt: 'a');
      final copied = goal.copyWith(targetMinutes: 20);
      expect(copied.targetMinutes, 20);
      expect(copied.updatedAt, 'a');
      expect(copied.copyWith(updatedAt: 'b').updatedAt, 'b');
      expect(copied.copyWith().targetMinutes, 20);
    });

    test('JSON 往復（toJson → fromJson）で復元できる', () {
      const goal = DailyReadingGoal(targetMinutes: 45, updatedAt: '2026-10-11');
      final restored = DailyReadingGoal.fromJson(goal.toJson());
      expect(restored, goal);
    });

    test('fromJson は非数値 targetMinutes を 0 に丸める', () {
      final goal = DailyReadingGoal.fromJson({'targetMinutes': 'abc'});
      expect(goal.targetMinutes, 0);
      expect(goal.updatedAt, '');
    });

    test('fromJson は負値 targetMinutes を 0 に丸める', () {
      final goal = DailyReadingGoal.fromJson({'targetMinutes': -5});
      expect(goal.targetMinutes, 0);
    });

    test('fromJson は updatedAt 欠落・非文字列を空文字にする', () {
      final goal = DailyReadingGoal.fromJson({'targetMinutes': 10});
      expect(goal.updatedAt, '');
      final goal2 = DailyReadingGoal.fromJson(
        {'targetMinutes': 10, 'updatedAt': 123},
      );
      expect(goal2.updatedAt, '');
    });

    test('等価性と hashCode', () {
      const a = DailyReadingGoal(targetMinutes: 30, updatedAt: 'x');
      const b = DailyReadingGoal(targetMinutes: 30, updatedAt: 'x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const DailyReadingGoal(targetMinutes: 30)));
    });
  });
}
