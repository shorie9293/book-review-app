import 'package:book_review_app/features/goals/domain/daily_reading_goal.dart';
import 'package:book_review_app/features/goals/domain/daily_reading_goal_service.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingSession session(String id, DateTime startedAt, int minutes) =>
    ReadingSession(id: id, startedAt: startedAt, durationMinutes: minutes);

void main() {
  group('dateKey', () {
    test('YYYY-MM-DD にゼロ埋めする', () {
      // ローカル日付コンストラクタで組む（TZ禍津回避）
      final dt = DateTime(2026, 10, 11, 9, 0);
      expect(DailyReadingGoalService.dateKey(dt), '2026-10-11');
      expect(
        DailyReadingGoalService.dateKey(DateTime(2026, 1, 5)),
        '2026-01-05',
      );
    });
  });

  group('minutesByDate', () {
    test('複数セッションをローカル日付ごとに合算する', () {
      final sessions = [
        session('a', DateTime(2026, 10, 11, 9, 0), 30),
        session('b', DateTime(2026, 10, 11, 21, 0), 20),
        session('c', DateTime(2026, 10, 10, 9, 0), 15),
      ];
      final map = DailyReadingGoalService.minutesByDate(sessions);
      expect(map['2026-10-11'], 50);
      expect(map['2026-10-10'], 15);
      expect(map.length, 2);
    });
  });

  group('build', () {
    test('未設定目標ではストリークは 0', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final progress = DailyReadingGoalService.build(
        sessions: [session('a', DateTime(2026, 10, 11, 9, 0), 60)],
        goal: const DailyReadingGoal.empty(),
        now: now,
      );
      expect(progress.isSet, isFalse);
      expect(progress.currentStreak, 0);
      expect(progress.longestStreak, 0);
      expect(progress.todayRatio, 0);
      expect(progress.todayMinutes, 60);
      expect(progress.todayAchieved, isFalse);
    });

    test('今日未達成でも昨日まで連続達成なら currentStreak を継続', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final sessions = [
        session('a', DateTime(2026, 10, 10, 9, 0), 60),
        session('b', DateTime(2026, 10, 9, 9, 0), 60),
        // 今日は 10分のみ（未達成）
        session('c', DateTime(2026, 10, 11, 9, 0), 10),
      ];
      final progress = DailyReadingGoalService.build(
        sessions: sessions,
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.todayAchieved, isFalse);
      expect(progress.currentStreak, 2);
    });

    test('今日達成なら今日からカウント', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final progress = DailyReadingGoalService.build(
        sessions: [session('a', DateTime(2026, 10, 11, 9, 0), 60)],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.todayAchieved, isTrue);
      expect(progress.currentStreak, 1);
    });

    test('longestStreak は暦上の最長連続（今日は未達成でも数える）', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final sessions = [
        // 10/4〜10/6 に連続達成、10/8 は欠かす
        session('a', DateTime(2026, 10, 4, 9, 0), 60),
        session('b', DateTime(2026, 10, 5, 9, 0), 60),
        session('c', DateTime(2026, 10, 6, 9, 0), 60),
        session('d', DateTime(2026, 10, 8, 9, 0), 60),
        session('e', DateTime(2026, 10, 9, 9, 0), 60),
        session('f', DateTime(2026, 10, 11, 9, 0), 5),
      ];
      final progress = DailyReadingGoalService.build(
        sessions: sessions,
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.longestStreak, 3);
      expect(progress.currentStreak, 0); // 10/10 にセッションがないため途切れ
    });

    test('todayRatio は超過で 1.0 にクランプ', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final progress = DailyReadingGoalService.build(
        sessions: [session('a', DateTime(2026, 10, 11, 9, 0), 90)],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.todayRatio, 1.0);
      expect(progress.achievedDaysInWindow, 1);
    });

    test('lastSevenDays は必ず7件・昇順', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final progress = DailyReadingGoalService.build(
        sessions: const [],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.lastSevenDays.length, 7);
      expect(progress.lastSevenDays.first.date, '2026-10-05');
      expect(progress.lastSevenDays.last.date, '2026-10-11');
      final dates = progress.lastSevenDays.map((d) => d.date).toList();
      expect(dates, equals(dates.toList()..sort()));
    });
  });
}
