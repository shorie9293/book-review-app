/// 親探針（合成の不変条件）: 日次読書目標
///
/// 眷属が個別にしか撃たない「合成」を検証する。
/// 1) 画面→純粋サービス→表示 の合成（実セッションを注入して今日の分数が出るか）
/// 2) 保存が永続化（リポジトリ）に到達し、別インスタンスの画面で復元されるか
/// 3) 達成境界（ちょうど目標分は達成。ratio はちょうど 1.0）
/// 4) 未設定時の空状態
library;

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/goals/data/daily_reading_goal_repository.dart';
import 'package:book_review_app/features/goals/domain/daily_reading_goal.dart';
import 'package:book_review_app/features/goals/domain/daily_reading_goal_service.dart';
import 'package:book_review_app/features/goals/presentation/daily_reading_goal_screen.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// すべてローカル日付で組む（CI は UTC で走るため TZ 依存を排除する）。
final DateTime _now = DateTime(2026, 10, 11, 21, 0);

ReadingSession _session(String id, DateTime startedAt, int minutes) =>
    ReadingSession(id: id, startedAt: startedAt, durationMinutes: minutes);

Future<void> _pump(
  WidgetTester tester, {
  required Key key,
  required DailyReadingGoalRepository goals,
  required ReadingSessionRepository sessions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DailyReadingGoalScreen(
        key: key,
        goalRepositoryOverride: goals,
        sessionRepositoryOverride: sessions,
        now: () => _now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('合成: 実セッションを注入すると今日の分数・進捗・ストリークが表示に反映される',
      (tester) async {
    final sessions = InMemoryReadingSessionRepository();
    // 今日: 25 + 15 = 40分（目標 30分を超過）
    await sessions.add(_session('a', DateTime(2026, 10, 11, 9, 0), 25));
    await sessions.add(_session('b', DateTime(2026, 10, 11, 20, 0), 15));
    final goals =
        InMemoryDailyReadingGoalRepository(initial: const DailyReadingGoal(targetMinutes: 30));

    await _pump(tester,
        key: const Key('probe1'), goals: goals, sessions: sessions);

    expect(find.text('今日 40分 / 目標 30分'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(AppKeys.dailyGoalProgressBar));
    expect(bar.value, 1.0); // 超過はクランプ
    expect(find.text('連続 1日達成（最長 1日）'), findsOneWidget);
    // 直近7日セルが7件・今日のセルに 40分 が出る
    expect(find.byKey(AppKeys.dailyGoalDayCell('2026-10-11')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(AppKeys.dailyGoalDayCell('2026-10-11')),
        matching: find.text('40分'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('合成: 保存が永続化に到達し、別インスタンスの画面で復元される', (tester) async {
    final goals = InMemoryDailyReadingGoalRepository();
    final sessions = InMemoryReadingSessionRepository();

    await _pump(tester,
        key: const Key('probeA'), goals: goals, sessions: sessions);
    expect(find.byKey(AppKeys.dailyGoalEmpty), findsOneWidget); // 未設定

    await tester.tap(find.byKey(AppKeys.dailyGoalPresetChip(45)));
    await tester.pumpAndSettle();

    // リポジトリまで到達しているか（state だけ更新する型を撃つ）
    expect(goals.current.targetMinutes, 45);

    // 別インスタンスの画面（新しい State）で復元されるか
    await _pump(tester,
        key: const Key('probeB'), goals: goals, sessions: sessions);
    expect(find.byKey(AppKeys.dailyGoalEmpty), findsNothing);
    expect(find.text('今日 0分 / 目標 45分'), findsOneWidget);
  });

  test('達成境界: ちょうど目標分は達成・ratio はちょうど 1.0', () {
    final sessions = [
      _session('a', DateTime(2026, 10, 11, 9, 0), 30),
      _session('b', DateTime(2026, 10, 10, 9, 0), 30),
    ];
    final progress = DailyReadingGoalService.build(
      sessions: sessions,
      goal: const DailyReadingGoal(targetMinutes: 30),
      now: _now,
    );
    expect(progress.todayAchieved, isTrue);
    expect(progress.todayMinutes, 30);
    expect(progress.todayRatio, 1.0);
    expect(progress.currentStreak, 2);
    expect(progress.longestStreak, 2);
    expect(progress.achievedDaysInWindow, 2);
  });

  test('未設定: 目標0なら進捗はゼロ・達成扱いにならない', () {
    final progress = DailyReadingGoalService.build(
      sessions: [_session('a', DateTime(2026, 10, 11, 9, 0), 60)],
      goal: const DailyReadingGoal.empty(),
      now: _now,
    );
    expect(progress.isSet, isFalse);
    expect(progress.todayAchieved, isFalse);
    expect(progress.todayRatio, 0.0);
    expect(progress.currentStreak, 0);
  });
}
