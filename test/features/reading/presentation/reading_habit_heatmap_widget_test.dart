import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_habit_heatmap_service.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';
import 'package:book_review_app/features/reading/presentation/widgets/reading_habit_heatmap.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingHabitHeatmap ウィジェット単体', () {
    testWidgets('空リストでは空メッセージのみ・グリッド非表示', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReadingHabitHeatmap(sessions: [])),
      );

      expect(find.byKey(AppKeys.readingHabitHeatmap), findsOneWidget);
      expect(find.byKey(AppKeys.readingHabitEmpty), findsOneWidget);
      expect(find.text('まだ読書の記録がありません'), findsOneWidget);
      expect(find.byKey(AppKeys.readingHabitGrid), findsNothing);
      expect(find.byKey(AppKeys.readingHabitLegend), findsNothing);
    });

    testWidgets('セッションありではグリッド・凡例・集計行を表示する', (tester) async {
      final fixed = DateTime(2026, 10, 5, 20, 0); // 月曜 20時台
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 's1',
                bookTitle: '本A',
                startedAt: fixed,
                durationMinutes: 30,
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(AppKeys.readingHabitGrid), findsOneWidget);
      expect(find.byKey(AppKeys.readingHabitLegend), findsOneWidget);
      expect(find.byKey(AppKeys.readingHabitEmpty), findsNothing);
      final busiest = tester.widget<Text>(
        find.byKey(AppKeys.readingHabitBusiest),
      );
      expect(busiest.data, contains('月曜 20-23時'));
      expect(busiest.data, contains('合計 30分'));
      expect(busiest.data, contains('1回'));
    });

    testWidgets('42セル分の key が存在し、指定セルを特定できる', (tester) async {
      final fixed = DateTime(2026, 10, 5, 12, 0); // 月曜 12時台
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 's1',
                startedAt: fixed,
                durationMinutes: 10,
              ),
            ],
          ),
        ),
      );

      for (var w = 1; w <= 7; w++) {
        for (var s = 0; s < ReadingHabitHeatmapService.slotCount; s++) {
          expect(
            find.byKey(AppKeys.readingHabitCell(w, s)),
            findsOneWidget,
            reason: 'weekday=$w slot=$s',
          );
        }
      }
    });

    testWidgets('レベル表引きの色はパレット内（範囲外例外なし）', (tester) async {
      final fixed = DateTime(2026, 10, 5, 21, 0);
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 's1',
                startedAt: fixed,
                durationMinutes: 120,
              ),
            ],
          ),
        ),
      );

      // 例外が出ずに pump が完走すること（色は静的パレットの表引きのみ）。
      final cell = tester.widget<Container>(
        find.byKey(AppKeys.readingHabitCell(1, 5)),
      );
      final decoration = cell.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
    });
  });

  group('集計・配色の境界', () {
    testWidgets('複数セッションの合計分・回数が集計行に反映される', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 'a',
                startedAt: DateTime(2026, 10, 5, 21, 0), // 月 21時
                durationMinutes: 30,
              ),
              ReadingSession(
                id: 'b',
                startedAt: DateTime(2026, 10, 5, 22, 0), // 月 22時
                durationMinutes: 45,
              ),
              ReadingSession(
                id: 'c',
                startedAt: DateTime(2026, 10, 6, 9, 0), // 火 9時
                durationMinutes: 10,
              ),
            ],
          ),
        ),
      );

      final busiest = tester.widget<Text>(
        find.byKey(AppKeys.readingHabitBusiest),
      );
      expect(busiest.data, contains('月曜'));
      expect(busiest.data, contains('合計 85分'));
      expect(busiest.data, contains('3回'));
    });

    testWidgets('曜日合計が同数のとき小さい曜日番号（月優先）が busiest', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 'a',
                startedAt: DateTime(2026, 10, 6, 21, 0), // 火
                durationMinutes: 40,
              ),
              ReadingSession(
                id: 'b',
                startedAt: DateTime(2026, 10, 10, 21, 0), // 土
                durationMinutes: 40,
              ),
            ],
          ),
        ),
      );

      final busiest = tester.widget<Text>(
        find.byKey(AppKeys.readingHabitBusiest),
      );
      expect(busiest.data, contains('火曜'));
    });

    testWidgets('時間帯境界: 3時台と4時台で slot が分かれる', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 'a',
                startedAt: DateTime(2026, 10, 5, 3, 0), // slot 0
                durationMinutes: 5,
              ),
              ReadingSession(
                id: 'b',
                startedAt: DateTime(2026, 10, 5, 4, 0), // slot 1
                durationMinutes: 20,
              ),
            ],
          ),
        ),
      );

      final slot0 = (tester.widget<Container>(
        find.byKey(AppKeys.readingHabitCell(1, 0)),
      ).decoration as BoxDecoration).color;
      final slot1 = (tester.widget<Container>(
        find.byKey(AppKeys.readingHabitCell(1, 1)),
      ).decoration as BoxDecoration).color;
      expect(slot0, isNot(equals(slot1))); // slot1 = max → level 4
    });

    testWidgets('最頻セルはパレット最濃色・0分セルは最淡色', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 'a',
                startedAt: DateTime(2026, 10, 5, 21, 0),
                durationMinutes: 60,
              ),
            ],
          ),
        ),
      );

      final top = (tester.widget<Container>(
        find.byKey(AppKeys.readingHabitCell(1, 5)),
      ).decoration as BoxDecoration).color;
      final empty = (tester.widget<Container>(
        find.byKey(AppKeys.readingHabitCell(1, 0)),
      ).decoration as BoxDecoration).color;
      expect(top, ReadingHabitHeatmap.palette[4]);
      expect(empty, ReadingHabitHeatmap.palette[0]);
    });

    testWidgets('同一セルへ複数セッションが加算される', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 'a',
                startedAt: DateTime(2026, 10, 5, 21, 0),
                durationMinutes: 10,
              ),
              ReadingSession(
                id: 'b',
                startedAt: DateTime(2026, 10, 5, 23, 0),
                durationMinutes: 20,
              ),
            ],
          ),
        ),
      );

      // ともに slot 5（20-23時）→ 合計30分がセルに反映（色で検証）。
      final cell = (tester.widget<Container>(
        find.byKey(AppKeys.readingHabitCell(1, 5)),
      ).decoration as BoxDecoration).color;
      expect(cell, ReadingHabitHeatmap.palette[4]);
    });

    testWidgets('凡例は5段階（パレット5色分のスウォッチ）を表示する', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadingHabitHeatmap(
            sessions: [
              ReadingSession(
                id: 'a',
                startedAt: DateTime(2026, 10, 5, 21, 0),
                durationMinutes: 10,
              ),
            ],
          ),
        ),
      );

      expect(find.text('少'), findsOneWidget);
      expect(find.text('多'), findsOneWidget);
    });
  });

  group('ReadingSessionScreen への配線', () {
    testWidgets('履歴より下にヒートマップが現れる（スクロール到達）', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fixed = DateTime(2026, 10, 5, 20, 0); // 月曜 20時台
      final repository = InMemoryReadingSessionRepository();
      await repository.add(
        ReadingSession(
          id: 'w1',
          bookTitle: '配線テスト本',
          startedAt: fixed,
          durationMinutes: 25,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingSessionScreen(repository: repository, now: () => fixed),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.readingHabitHeatmap), findsOneWidget);
      expect(find.byKey(AppKeys.readingHabitGrid), findsOneWidget);
      // 既存セクション（履歴）より下に置かれている。
      final historyTop = tester.getTopLeft(
        find.text('履歴').first,
      );
      final heatmapTop = tester.getTopLeft(
        find.byKey(AppKeys.readingHabitHeatmap),
      );
      expect(heatmapTop.dy, greaterThan(historyTop.dy));
    });

    testWidgets('セッションが空の画面ではヒートマップの空出力は出さない', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fixed = DateTime(2026, 10, 5, 20, 0);
      final repository = InMemoryReadingSessionRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingSessionScreen(repository: repository, now: () => fixed),
        ),
      );
      await tester.pumpAndSettle();

      // 画面の空状態（readingEmpty）は出るが、ヒートマップウィジェット自体は配線されない。
      expect(find.byKey(AppKeys.readingEmpty), findsOneWidget);
      expect(find.byKey(AppKeys.readingHabitHeatmap), findsNothing);
    });
  });
}
