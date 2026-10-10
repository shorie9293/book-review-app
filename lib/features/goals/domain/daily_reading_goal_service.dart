/// 日次読書目標の純粋ロジック
///
/// ReadingSession 一覧から日別の読書時間を集計し、目標に対する
/// 進捗・ストリークを算出する。UI・永続化に依存しない。
library;

import 'package:book_review_app/features/goals/domain/daily_reading_goal.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

/// 1日分の集計結果
class DailyGoalDay {
  /// 'YYYY-MM-DD'（ローカル日付）
  final String date;

  /// その日の合計読書時間（0以上）
  final int minutes;

  /// 目標分（0 = 未設定）
  final int target;

  const DailyGoalDay({
    required this.date,
    required this.minutes,
    required this.target,
  });

  bool get isAchieved => target > 0 && minutes >= target;
}

/// 日次目標に対する進捗
class DailyGoalProgress {
  /// 'YYYY-MM-DD'（今日のローカル日付）
  final String today;

  /// 今日の合計読書分数（0以上）
  final int todayMinutes;

  /// 目標分（0 = 未設定）
  final int target;

  /// 現在の連続達成日数
  final int currentStreak;

  /// 最長連続達成日数
  final int longestStreak;

  /// now-6 .. now の7件（昇順・必ず7件）
  final List<DailyGoalDay> lastSevenDays;

  const DailyGoalProgress({
    required this.today,
    required this.todayMinutes,
    required this.target,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSevenDays,
  });

  bool get isSet => target > 0;

  bool get todayAchieved => target > 0 && todayMinutes >= target;

  /// 進捗率（0.0〜1.0。未設定時 0、超過は 1.0 にクランプ）
  double get todayRatio {
    if (!isSet) return 0;
    final value = todayMinutes / target;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  /// 直近7日中の達成日数
  int get achievedDaysInWindow =>
      lastSevenDays.where((d) => d.isAchieved).length;
}

class DailyReadingGoalService {
  const DailyReadingGoalService._();

  /// ローカル日付 → 'YYYY-MM-DD'（ゼロ埋め）
  static String dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// セッションを読書分数にして日付キーへ合算する。
  /// startedAt はローカル時刻の DateTime なので toLocal() の日付を使う。
  static Map<String, int> minutesByDate(List<ReadingSession> sessions) {
    final map = <String, int>{};
    for (final session in sessions) {
      final key = dateKey(session.startedAt.toLocal());
      map[key] = (map[key] ?? 0) + session.durationMinutes;
    }
    return map;
  }

  /// 進捗を構築する
  static DailyGoalProgress build({
    required List<ReadingSession> sessions,
    required DailyReadingGoal goal,
    required DateTime now,
  }) {
    final map = minutesByDate(sessions);
    final today = dateKey(now);
    final todayMinutes = map[today] ?? 0;

    // 直近7日（now-6 .. now、昇順）
    final lastSevenDays = <DailyGoalDay>[];
    for (var i = 6; i >= 0; i--) {
      final date = dateKey(now.subtract(Duration(days: i)));
      lastSevenDays.add(DailyGoalDay(
        date: date,
        minutes: map[date] ?? 0,
        target: goal.targetMinutes,
      ));
    }

    final target = goal.targetMinutes;
    if (target <= 0) {
      return DailyGoalProgress(
        today: today,
        todayMinutes: todayMinutes < 0 ? 0 : todayMinutes,
        target: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastSevenDays: lastSevenDays,
      );
    }

    // 現在のストリーク: 今日が達成なら今日から、未達成なら昨日から遡る
    var currentStreak = 0;
    final todayAchieved = todayMinutes >= target;
    var cursor = DateTime(now.year, now.month, now.day);
    if (!todayAchieved) cursor = cursor.subtract(const Duration(days: 1));
    while ((map[dateKey(cursor)] ?? 0) >= target) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // 最長ストリーク: 達成日のみを暦上連続で並べた最長
    final achievedDates = map.keys
        .where((k) => (map[k] ?? 0) >= target)
        .toList()
      ..sort();
    var longestStreak = 0;
    var run = 0;
    DateTime? prev;
    for (final dateStr in achievedDates) {
      final parts = dateStr.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final isAdjacent =
          prev != null && date.difference(prev) == const Duration(days: 1);
      run = isAdjacent ? run + 1 : 1;
      if (run > longestStreak) longestStreak = run;
      prev = date;
    }

    return DailyGoalProgress(
      today: today,
      todayMinutes: todayMinutes < 0 ? 0 : todayMinutes,
      target: target,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastSevenDays: lastSevenDays,
    );
  }
}
