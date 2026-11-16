import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';

/// add 呼出回数を数え、任意の時点で保存を保留・失敗させられるリポジトリ。
///
/// 保留（[holdNextAdd]）は「保存中」の再入窓を試練で開くために使う。
class CountingRepository implements ReadingSessionRepository {
  /// add が呼ばれたセッション（回数計数用・失敗分も含む）。
  final List<ReadingSession> attempted = [];

  /// 実際に永続化されたセッション。
  final List<ReadingSession> stored = [];

  /// 設定すると add がこの Completer の完了まで待つ。
  Completer<void>? gate;

  /// 残り何回 add を失敗させるか。
  int failuresToThrow = 0;

  /// 失敗時に投げる例外。
  Object failure = StateError('保存失敗');

  int get addCount => attempted.length;

  @override
  Future<void> add(ReadingSession session) async {
    attempted.add(session);
    final g = gate;
    if (g != null) await g.future;
    if (failuresToThrow > 0) {
      failuresToThrow--;
      throw failure;
    }
    stored.add(session);
  }

  @override
  Future<List<ReadingSession>> loadAll() async => List.of(stored);

  @override
  Future<void> update(ReadingSession session) async {}

  @override
  Future<void> remove(String id) async {}
}

void main() {
  final base = DateTime(2026, 10, 4, 12, 0);

  Future<void> pumpScreen(
    WidgetTester tester,
    CountingRepository repository,
    DateTime Function() now,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingSessionScreen(repository: repository, now: now),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 開始→2分経過→停止 まで進め、保存待ち状態にする。
  Future<void> stopWithTwoMinutes(
    WidgetTester tester,
    void Function(DateTime) setNow,
  ) async {
    await tester.tap(find.byKey(AppKeys.readingStart));
    await tester.pump();
    setNow(base.add(const Duration(seconds: 125)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(AppKeys.readingStop));
    await tester.pump();
  }

  group('読書時間 保存の二度押し（再入ガード）', () {
    testWidgets('保存中に二度押ししても add は1回しか走らない', (tester) async {
      var current = base;
      final repository = CountingRepository();
      await pumpScreen(tester, repository, () => current);
      await stopWithTwoMinutes(tester, (v) => current = v);

      // 1回目の保存を保留させ、保存中の窓を開く。
      repository.gate = Completer<void>();
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();
      expect(repository.addCount, 1);

      // フレームを挟まない連続タップ（再入ガードの検証）。
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();
      expect(repository.addCount, 1, reason: '保存中の再入で add が二重に走ってはならない');

      // 保留を解除すると1回分だけ永続化される。
      repository.gate!.complete();
      repository.gate = null;
      await tester.pumpAndSettle();

      expect(repository.stored, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('保存中は保存ボタンが無効になる', (tester) async {
      var current = base;
      final repository = CountingRepository();
      await pumpScreen(tester, repository, () => current);
      await stopWithTwoMinutes(tester, (v) => current = v);

      repository.gate = Completer<void>();
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(AppKeys.readingStop),
      );
      expect(button.onPressed, isNull, reason: '保存中は押せてはならない');

      repository.gate!.complete();
      repository.gate = null;
      await tester.pumpAndSettle();

      // 保存完了後は開始ボタンへ戻る。
      expect(find.byKey(AppKeys.readingStart), findsOneWidget);
      expect(repository.stored, hasLength(1));
    });

    testWidgets('保存失敗時は確定分が戻り、理由を示して再試行できる', (tester) async {
      var current = base;
      final repository = CountingRepository()..failuresToThrow = 1;
      await pumpScreen(tester, repository, () => current);
      await stopWithTwoMinutes(tester, (v) => current = v);
      expect(find.text('2分が確定しました'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pumpAndSettle();

      // 失敗：保存されず、確定分は失われず、理由が画面出る。
      expect(repository.addCount, 1);
      expect(repository.stored, isEmpty);
      expect(find.text('2分が確定しました'), findsOneWidget);
      expect(find.byKey(const Key('reading_save_failed')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 再試行：2回目は成功し、下書きも確定分も片付く。
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pumpAndSettle();

      expect(repository.addCount, 2);
      expect(repository.stored, hasLength(1));
      expect(repository.stored.single.durationMinutes, 2);
      expect(find.text('2分が確定しました'), findsNothing);
      expect(find.text('2分'), findsNWidgets(2)); // 統計 + 日別行
      expect(tester.takeException(), isNull);
    });

    testWidgets('保存成功時は再入不可のまま画面が壊れない', (tester) async {
      var current = base;
      final repository = CountingRepository();
      await pumpScreen(tester, repository, () => current);
      await stopWithTwoMinutes(tester, (v) => current = v);

      // 待ちを挟まない連続2タップ（同期的な再入）。
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pumpAndSettle();

      expect(repository.addCount, 1);
      expect(repository.stored, hasLength(1));
      expect(find.byKey(AppKeys.readingStart), findsOneWidget);
      expect(find.text('2分'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
