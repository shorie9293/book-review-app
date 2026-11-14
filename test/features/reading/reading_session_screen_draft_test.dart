import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/data/reading_session_draft_store.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session_draft.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';

/// 書き込み・読み込みで必ず失敗する下書き保存先（I/O 失敗の模擬）。
class ThrowingDraftStore implements ReadingSessionDraftStore {
  bool shouldThrowOnRead = true;

  @override
  Future<ReadingSessionDraft?> read() async {
    if (shouldThrowOnRead) throw StateError('読み込み失敗');
    return null;
  }

  @override
  Future<void> write(ReadingSessionDraft draft) async {
    throw StateError('書き込み失敗');
  }

  @override
  Future<void> clear() async {
    throw StateError('削除失敗');
  }
}

void main() {
  final base = DateTime(2026, 10, 4, 12, 0);

  Future<void> pumpScreen(
    WidgetTester tester,
    InMemoryReadingSessionRepository repository, {
    required DateTime Function() now,
    ReadingSessionDraftStore? draftStore,
  }) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingSessionScreen(
          repository: repository,
          now: now,
          draftStore: draftStore,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('走行中セッションの下書き', () {
    testWidgets('開始→離脱→再入場で経過が継続する', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      final store = InMemoryReadingSessionDraftStore();

      await pumpScreen(tester, repository,
          now: () => current, draftStore: store);

      await tester.tap(find.byKey(AppKeys.readingStart));
      await tester.pump();

      // 開始時点で下書きが書かれている（UTC 瞬間として）
      expect(store.raw, isNotNull);
      expect(store.raw as String, contains('Z'));

      current = base.add(const Duration(seconds: 125));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('02:05'), findsOneWidget);

      // 画面破棄（アプリ離脱相当）→ 走行中なので下書きが残る
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(store.raw, isNotNull);

      // 3分後に再入場 → 開始時刻から継続
      current = base.add(const Duration(seconds: 180));
      await pumpScreen(tester, repository,
          now: () => current, draftStore: store);

      expect(find.byKey(AppKeys.readingElapsed), findsOneWidget);
      expect(find.text('03:00'), findsOneWidget);
      expect(find.text('走行中セッションを復帰しました'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('停止→保存すると下書きは消える', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      final store = InMemoryReadingSessionDraftStore();

      await pumpScreen(tester, repository,
          now: () => current, draftStore: store);

      await tester.tap(find.byKey(AppKeys.readingStart));
      await tester.pump();
      expect(store.raw, isNotNull);

      current = base.add(const Duration(seconds: 125));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();
      // 停止しただけでは下書きは消さない（保存成功後に消す）
      expect(store.raw, isNotNull);

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pumpAndSettle();

      expect(repository.length, 1);
      final saved = await repository.loadAll();
      expect(saved.first.durationMinutes, 2);
      expect(store.raw, isNull);
      expect(store.clearCount, 1);
    });

    testWidgets('壊れた下書きで起動しても落ちない', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      final store =
          InMemoryReadingSessionDraftStore(raw: '{"startedAt": "壊れた値"}');

      await pumpScreen(tester, repository,
          now: () => current, draftStore: store);

      expect(tester.takeException(), isNull);
      expect(find.byKey(AppKeys.readingElapsed), findsNothing);
      expect(find.byKey(AppKeys.readingStart), findsOneWidget);
    });

    testWidgets('復帰時に長時間経過していても throw せず、経過を出す', (tester) async {
      final current = base;
      final repository = InMemoryReadingSessionRepository();
      final store = InMemoryReadingSessionDraftStore();
      await store.write(ReadingSessionDraft(
        startedAt: base.subtract(const Duration(hours: 10)),
      ));

      await pumpScreen(tester, repository,
          now: () => current, draftStore: store);

      expect(tester.takeException(), isNull);
      expect(find.byKey(AppKeys.readingElapsed), findsOneWidget);
      expect(find.text('600:00'), findsOneWidget);
    });

    testWidgets('未来時刻の下書きで復帰しても throw せず 00:00 に丸める', (tester) async {
      final current = base;
      final repository = InMemoryReadingSessionRepository();
      final store = InMemoryReadingSessionDraftStore();
      await store.write(ReadingSessionDraft(
        startedAt: base.add(const Duration(hours: 2)),
      ));

      await pumpScreen(tester, repository,
          now: () => current, draftStore: store);

      expect(tester.takeException(), isNull);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('下書き I/O が失敗しても画面は動き続ける', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      final store = ThrowingDraftStore();

      await pumpScreen(tester, repository,
          now: () => current, draftStore: store);

      // 読み込み失敗でも起動は成立する
      expect(find.byKey(AppKeys.readingStart), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.readingStart));
      await tester.pump();
      expect(find.byKey(AppKeys.readingElapsed), findsOneWidget);

      // 走行中に破棄（dispose の書き込みも失敗する）→ 落ちない
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
