import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/goals/data/daily_reading_goal_repository.dart';
import 'package:book_review_app/features/goals/domain/daily_reading_goal.dart';
import 'package:book_review_app/features/goals/presentation/daily_reading_goal_screen.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

/// テスト用の固定セッションリポジトリ。
class FakeSessionRepository implements ReadingSessionRepository {
  FakeSessionRepository(this._sessions);

  final List<ReadingSession> _sessions;

  @override
  Future<List<ReadingSession>> loadAll() async => List.of(_sessions);

  @override
  Future<void> add(ReadingSession session) async => _sessions.add(session);

  @override
  Future<void> update(ReadingSession session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = session;
  }

  @override
  Future<void> remove(String id) async =>
      _sessions.removeWhere((s) => s.id == id);
}

ReadingSession sessionAt(DateTime date, int minutes, String id) =>
    ReadingSession(
      id: id,
      startedAt: date,
      durationMinutes: minutes,
    );

Future<void> pumpScreen(
  WidgetTester tester, {
  required InMemoryDailyReadingGoalRepository goalRepository,
  required FakeSessionRepository sessionRepository,
  required DateTime now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DailyReadingGoalScreen(
        goalRepositoryOverride: goalRepository,
        sessionRepositoryOverride: sessionRepository,
        now: () => now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime(2026, 10, 11, 9, 0);

  testWidgets('画面が描画される', (tester) async {
    await pumpScreen(
      tester,
      goalRepository: InMemoryDailyReadingGoalRepository(),
      sessionRepository: FakeSessionRepository([]),
      now: now,
    );

    expect(find.byKey(AppKeys.dailyGoalScreen), findsOneWidget);
    expect(find.byKey(AppKeys.dailyGoalTodayCard), findsOneWidget);
    expect(find.byKey(AppKeys.dailyGoalEmpty), findsOneWidget);
  });

  testWidgets('プリセット選択→保存で repository.current が更新される', (tester) async {
    final goalRepository = InMemoryDailyReadingGoalRepository();
    await pumpScreen(
      tester,
      goalRepository: goalRepository,
      sessionRepository: FakeSessionRepository([]),
      now: now,
    );

    await tester.tap(find.byKey(AppKeys.dailyGoalPresetChip(30)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.dailyGoalSaveButton));
    await tester.pumpAndSettle();

    expect(goalRepository.current.targetMinutes, 30);
    expect(goalRepository.current.updatedAt, isNotEmpty);
    // 保存後に再読込され「目標未設定」が消える
    expect(find.byKey(AppKeys.dailyGoalEmpty), findsNothing);
  });

  testWidgets('数値入力→保存で repository.current が更新される', (tester) async {
    final goalRepository = InMemoryDailyReadingGoalRepository();
    await pumpScreen(
      tester,
      goalRepository: goalRepository,
      sessionRepository: FakeSessionRepository([]),
      now: now,
    );

    await tester.enterText(
      find.byKey(AppKeys.dailyGoalMinutesField),
      '25',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.dailyGoalSaveButton));
    await tester.pumpAndSettle();

    expect(goalRepository.current.targetMinutes, 25);
  });

  testWidgets('解除で 0 が保存される', (tester) async {
    final goalRepository = InMemoryDailyReadingGoalRepository(
      initial: const DailyReadingGoal(targetMinutes: 30, updatedAt: 'x'),
    );
    await pumpScreen(
      tester,
      goalRepository: goalRepository,
      sessionRepository: FakeSessionRepository([]),
      now: now,
    );

    await tester.tap(find.byKey(AppKeys.dailyGoalClearButton));
    await tester.pumpAndSettle();

    expect(goalRepository.current.targetMinutes, 0);
    expect(find.byKey(AppKeys.dailyGoalEmpty), findsOneWidget);
  });

  testWidgets('進捗バーと連続ラベルが表示される', (tester) async {
    // 今日: 30分 / 目標30 → 達成、昨日: 30分（達成）→ 連続2日
    final goalRepository = InMemoryDailyReadingGoalRepository(
      initial: DailyReadingGoal(targetMinutes: 30),
    );
    final sessions = FakeSessionRepository([
      sessionAt(now, 30, 's-today'),
      sessionAt(now.subtract(const Duration(days: 1)), 30, 's-yesterday'),
    ]);
    await pumpScreen(
      tester,
      goalRepository: goalRepository,
      sessionRepository: sessions,
      now: now,
    );

    expect(find.byKey(AppKeys.dailyGoalProgressBar), findsOneWidget);
    expect(find.byKey(AppKeys.dailyGoalStreakLabel), findsOneWidget);
    expect(find.text('連続 2日達成（最長 2日）'), findsOneWidget);
    expect(find.text('今日 30分 / 目標 30分'), findsOneWidget);
  });

  testWidgets('7日分のセルが7件表示される', (tester) async {
    await pumpScreen(
      tester,
      goalRepository: InMemoryDailyReadingGoalRepository(),
      sessionRepository: FakeSessionRepository([]),
      now: now,
    );

    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .substring(0, 10);
      expect(find.byKey(AppKeys.dailyGoalDayCell(key)), findsOneWidget);
    }
  });
}
