import 'package:book_review_app/features/goals/data/daily_reading_goal_repository.dart';
import 'package:book_review_app/features/goals/domain/daily_reading_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryDailyReadingGoalRepository', () {
    test('初期値なしは未設定、load/save が往復する', () async {
      final repo = InMemoryDailyReadingGoalRepository();
      expect(await repo.load(), const DailyReadingGoal.empty());
      expect(repo.current, const DailyReadingGoal.empty());

      const goal = DailyReadingGoal(targetMinutes: 60, updatedAt: 'u');
      await repo.save(goal);
      expect(await repo.load(), goal);
      expect(repo.current, goal);
    });

    test('ctor で初期値を注入できる', () async {
      const initial = DailyReadingGoal(targetMinutes: 20);
      final repo = InMemoryDailyReadingGoalRepository(initial: initial);
      expect(await repo.load(), initial);
    });
  });
}
