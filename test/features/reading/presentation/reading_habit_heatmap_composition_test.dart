import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_habit_heatmap_service.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';
import 'package:book_review_app/features/reading/presentation/widgets/reading_habit_heatmap.dart'
    as widget_hm;

/// 親探針：合成の不変条件を撃つ（眷属は個別操作しか撃たない）。
/// 画面→リポジトリ→集計 の合成・グリッド整合・閾値境界を検証する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReadingSession s(String id, DateTime at, int minutes,
          {String? title}) =>
      ReadingSession(
        id: id,
        bookTitle: title,
        startedAt: at,
        durationMinutes: minutes,
      );

  group('親探針: 合成の不変条件', () {
    testWidgets(
        '画面のヒートマップは「全セッション」を対象とし直近7日に限定されない',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime(2026, 10, 5, 20, 0); // 月曜
      final repository = InMemoryReadingSessionRepository();
      // 直近（7日以内）
      await repository.add(s('recent', DateTime(2026, 10, 5, 21, 0), 30));
      // 34日前（7日セクションからは外れる）
      await repository.add(s('old', DateTime(2026, 9, 1, 21, 0), 60));

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingSessionScreen(repository: repository, now: () => now),
        ),
      );
      await tester.pumpAndSettle();

      final busiest = tester.widget<Text>(
        find.byKey(AppKeys.readingHabitBusiest),
      );
      // 合計 90分・2回（古いセッションも含む）。
      expect(busiest.data, contains('合計 90分'));
      expect(busiest.data, contains('2回'));
    });

    test('グリッド整合: 42セルの合計 == totalMinutes・セル数は常に42', () {
      final sessions = [
        s('a', DateTime(2026, 10, 5, 1, 0), 30),
        s('b', DateTime(2026, 10, 6, 9, 0), 15),
        s('c', DateTime(2026, 10, 11, 23, 0), 45),
      ];
      final heatmap = ReadingHabitHeatmapService.build(sessions: sessions);
      final sum = heatmap.cells.fold<int>(0, (acc, c) => acc + c.minutes);
      expect(heatmap.cells.length, 7 * ReadingHabitHeatmapService.slotCount);
      expect(sum, heatmap.totalMinutes);
      expect(heatmap.totalMinutes, 90);
      expect(heatmap.totalSessions, 3);
      // 曜日合計と時間帯合計の総和は totalMinutes と一致する。
      expect(heatmap.weekdayTotals.fold<int>(0, (a, b) => a + b), 90);
      expect(heatmap.slotTotals.fold<int>(0, (a, b) => a + b), 90);
    });

    test('閾値境界: ratio 0.25/0.5/0.75 の equality は下位レベル', () {
      // 最大100分を作り、25/50/75/76 分のセルで level を確かめる。
      final sessions = [
        s('max', DateTime(2026, 10, 5, 0, 0), 100), // 月 slot0
        s('q1', DateTime(2026, 10, 5, 4, 0), 25), // 月 slot1
        s('q2', DateTime(2026, 10, 5, 8, 0), 50), // 月 slot2
        s('q3', DateTime(2026, 10, 5, 12, 0), 75), // 月 slot3
        s('q4', DateTime(2026, 10, 5, 16, 0), 76), // 月 slot4
      ];
      final heatmap = ReadingHabitHeatmapService.build(sessions: sessions);
      expect(heatmap.maxMinutes, 100);
      expect(heatmap.levelOf(heatmap.cellAt(1, 0)), 4); // 100/100
      expect(heatmap.levelOf(heatmap.cellAt(1, 1)), 1); // 0.25
      expect(heatmap.levelOf(heatmap.cellAt(1, 2)), 2); // 0.50
      expect(heatmap.levelOf(heatmap.cellAt(1, 3)), 3); // 0.75
      expect(heatmap.levelOf(heatmap.cellAt(1, 4)), 4); // 0.76
      expect(heatmap.levelOf(heatmap.cellAt(1, 5)), 0); // 0分
    });

    test('境界: 日曜(weekday=7)と23時台(slot=5)が正しいセルに入る', () {
      // 2026-10-11 は日曜。
      final heatmap = ReadingHabitHeatmapService.build(
        sessions: [s('sun', DateTime(2026, 10, 11, 23, 30), 40)],
      );
      expect(heatmap.cellAt(7, 5).minutes, 40);
      expect(heatmap.busiestWeekday, 7);
      expect(heatmap.busiestSlot, 5);
      expect(heatmap.busiestLabel, '日曜 20-23時');
    });

    test('不変: 空リストでもゼロ埋め42セル・busiest は null・例外なし', () {
      final heatmap = ReadingHabitHeatmapService.build(sessions: const []);
      expect(heatmap.cells.length, 42);
      expect(heatmap.isEmpty, isTrue);
      expect(heatmap.maxMinutes, 0);
      expect(heatmap.totalMinutes, 0);
      expect(heatmap.busiestWeekday, isNull);
      expect(heatmap.busiestSlot, isNull);
      expect(heatmap.busiestLabel, '—');
      for (final cell in heatmap.cells) {
        expect(cell.isEmpty, isTrue);
      }
    });

    testWidgets('画面経由のセルは実データの最大セルで最濃・ゼロセルで最淡', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime(2026, 10, 6, 22, 0);
      final repository = InMemoryReadingSessionRepository();
      // 火 slot5 に60分（最大）、水 slot2 に10分。
      await repository.add(s('max', DateTime(2026, 10, 6, 21, 0), 60));
      await repository.add(s('small', DateTime(2026, 10, 7, 9, 0), 10));

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingSessionScreen(repository: repository, now: () => now),
        ),
      );
      await tester.pumpAndSettle();

      Color colorOf(int weekday, int slot) => (tester
              .widget<Container>(find.byKey(AppKeys.readingHabitCell(weekday, slot)))
              .decoration as BoxDecoration)
          .color!;

      expect(colorOf(2, 5), widget_hm.ReadingHabitHeatmap.palette[4]); // 火 20-23時の最大
      expect(colorOf(3, 2), widget_hm.ReadingHabitHeatmap.palette[1]); // 水 8-11時の最小
      expect(colorOf(1, 0), widget_hm.ReadingHabitHeatmap.palette[0]); // 記録なし
    });

    testWidgets('合成: 手動追加したセッションが画面再読込でヒートマップに反映される',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime(2026, 10, 5, 20, 0);
      final repository = InMemoryReadingSessionRepository();
      await repository.add(s('a', DateTime(2026, 10, 5, 21, 0), 20));

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingSessionScreen(repository: repository, now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(AppKeys.readingHabitBusiest)).data,
        contains('合計 20分'),
      );

      // 手動追加ダイアログ経由（UI操作 → repository保存 → 画面再読込 → ヒートマップ）。
      await tester.tap(find.byKey(AppKeys.readingAddButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reading_manual_minutes_field')),
        '25',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(AppKeys.readingHabitBusiest)).data,
        contains('合計 45分'),
      );
      expect(await repository.loadAll(), hasLength(2));
    });
  });
}
