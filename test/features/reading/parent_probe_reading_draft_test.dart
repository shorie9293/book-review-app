import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/data/reading_session_draft_store.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';

/// 親探針（合成の不変条件）。
///
/// 子の試練は「下書きの読み書き」と「画面の1操作」を個別に撃つ。
/// ここでは画面を差し替えて「離脱→再入場」の合成だけを独立に撃つ。
void main() {
  final base = DateTime(2026, 10, 4, 12, 0);

  Widget wrap(InMemoryReadingSessionRepository repository, {
    required DateTime Function() now,
    required ReadingSessionDraftStore store,
  }) {
    return MaterialApp(
      home: ReadingSessionScreen(
        repository: repository,
        now: now,
        draftStore: store,
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    InMemoryReadingSessionRepository repository, {
    required DateTime Function() now,
    required ReadingSessionDraftStore store,
  }) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(repository, now: now, store: store),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('P1 計測中に離脱→再入場で経過が継続している（復帰導線が出る）',
      (tester) async {
    var current = base;
    final repository = InMemoryReadingSessionRepository();
    final store = InMemoryReadingSessionDraftStore();
    final now = () => current;

    await pumpScreen(tester, repository, now: now, store: store);
    await tester.tap(find.byKey(AppKeys.readingStart));
    await tester.pump();

    current = base.add(const Duration(minutes: 12, seconds: 30));
    // 離脱（dispose）→ 再入場
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    await pumpScreen(tester, repository, now: now, store: store);

    // 復帰導線が出ている
    expect(find.byKey(const Key('reading_draft_restored')), findsOneWidget);
    // 停止ボタン＝計測中として復帰している
    expect(find.byKey(AppKeys.readingStop), findsOneWidget);
    // 経過が 12 分台として表示されている（0 に戻っていない）
    expect(find.textContaining('12:'), findsWidgets);
  });

  testWidgets('P2 停止してから離脱した場合、再入場で計測は復活しない', (tester) async {
    var current = base;
    final repository = InMemoryReadingSessionRepository();
    final store = InMemoryReadingSessionDraftStore();
    final now = () => current;

    await pumpScreen(tester, repository, now: now, store: store);
    await tester.tap(find.byKey(AppKeys.readingStart));
    await tester.pump();
    current = base.add(const Duration(minutes: 5));
    await tester.tap(find.byKey(AppKeys.readingStop));
    await tester.pump();

    // 停止で下書きは捨てられる
    expect(store.raw, isNull);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    await pumpScreen(tester, repository, now: now, store: store);

    expect(find.byKey(const Key('reading_draft_restored')), findsNothing);
    expect(find.byKey(AppKeys.readingStart), findsOneWidget);
  });

  testWidgets('P3 壊れた下書きでも起動して落ちない', (tester) async {
    var current = base;
    final repository = InMemoryReadingSessionRepository();
    final store = InMemoryReadingSessionDraftStore(
      raw: '{"startedAt":"not-a-date"',
    );

    await pumpScreen(tester, repository, now: () => current, store: store);

    expect(tester.takeException(), isNull);
    expect(find.byKey(AppKeys.readingStart), findsOneWidget);
  });

  testWidgets('P4 下書きは保存形式（UTC瞬間）で書かれ、復帰でローカル表示が崩れない',
      (tester) async {
    var current = base;
    final repository = InMemoryReadingSessionRepository();
    final store = InMemoryReadingSessionDraftStore();
    final now = () => current;

    await pumpScreen(tester, repository, now: now, store: store);
    await tester.tap(find.byKey(AppKeys.readingStart));
    await tester.pump();

    final raw = store.raw;
    expect(raw, isNotNull);
    expect((raw as String).contains('Z'), isTrue, reason: 'UTC瞬間で保存する契約');

    current = base.add(const Duration(minutes: 3));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    await pumpScreen(tester, repository, now: now, store: store);

    // 復帰後も計測継続（3分台）
    expect(find.textContaining('03:'), findsWidgets);
  });
}
