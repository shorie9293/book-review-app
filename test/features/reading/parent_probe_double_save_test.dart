import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';

/// 親探針用：本番の [InMemoryReadingSessionRepository] を包み、
/// 「保存中」の窓を開くためだけに遅延を挟む（保存自体は本番実装が行う）。
class SlowRepository implements ReadingSessionRepository {
  SlowRepository(this._inner);

  final InMemoryReadingSessionRepository _inner;
  Duration delay = const Duration(seconds: 1);
  int failuresToThrow = 0;
  int addCount = 0;

  @override
  Future<void> add(ReadingSession session) async {
    addCount++;
    await Future<void>.delayed(delay);
    if (failuresToThrow > 0) {
      failuresToThrow--;
      throw StateError('保存失敗（探針）');
    }
    await _inner.add(session);
  }

  @override
  Future<List<ReadingSession>> loadAll() => _inner.loadAll();

  @override
  Future<void> update(ReadingSession session) => _inner.update(session);

  @override
  Future<void> remove(String id) => _inner.remove(id);
}

void main() {
  // 時刻はすべてローカル暦の固定値。実時計は使わない。
  final base = DateTime(2026, 10, 4, 12, 0);

  Future<void> pumpScreen(
    WidgetTester tester,
    ReadingSessionRepository repository,
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

  group('親探針: 保存の再入は「計上」を二重にしない', () {
    testWidgets('PP1 実リポジトリ合成: 二度押しでも永続化は1件・合計分は1回分', (tester) async {
      var current = base;
      final inner = InMemoryReadingSessionRepository();
      final repository = SlowRepository(inner);
      await pumpScreen(tester, repository, () => current);
      await stopWithTwoMinutes(tester, (v) => current = v);

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump(); // 保存中（遅延の窓）
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final stored = await inner.loadAll();
      expect(stored, hasLength(1), reason: '同一セッションが2件できてはならない');
      expect(
        stored.fold<int>(0, (sum, s) => sum + s.durationMinutes),
        2,
        reason: '読書時間が二重計上されてはならない（2分の1回分のみ）',
      );
      expect(repository.addCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PP2 失敗後の再試行: 確定分が保たれ、計上は1回分だけ', (tester) async {
      var current = base;
      final inner = InMemoryReadingSessionRepository();
      final repository = SlowRepository(inner)..failuresToThrow = 1;
      await pumpScreen(tester, repository, () => current);
      await stopWithTwoMinutes(tester, (v) => current = v);

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(await inner.loadAll(), isEmpty, reason: '失敗分は永続化されてはならない');
      expect(find.text('2分が確定しました'), findsOneWidget, reason: '確定分が失われてはならない');
      final button = tester.widget<FilledButton>(find.byKey(AppKeys.readingStop));
      expect(button.onPressed, isNotNull, reason: '失敗後は再試行できなければならない');

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final stored = await inner.loadAll();
      expect(stored, hasLength(1));
      expect(stored.single.durationMinutes, 2);
      expect(repository.addCount, 2, reason: '失敗1回＋成功1回のみ');
      expect(tester.takeException(), isNull);
    });

    testWidgets('PP3 フレームを挟まない連続2タップでも1回', (tester) async {
      var current = base;
      final inner = InMemoryReadingSessionRepository();
      final repository = SlowRepository(inner)..delay = Duration.zero;
      await pumpScreen(tester, repository, () => current);
      await stopWithTwoMinutes(tester, (v) => current = v);

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pumpAndSettle();

      expect(repository.addCount, 1);
      expect(await inner.loadAll(), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('PP4 保存中のボタンは無効・保存後は開始へ戻る', (tester) async {
      var current = base;
      final inner = InMemoryReadingSessionRepository();
      final repository = SlowRepository(inner);
      await pumpScreen(tester, repository, () => current);
      await stopWithTwoMinutes(tester, (v) => current = v);

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();
      final saving = tester.widget<FilledButton>(find.byKey(AppKeys.readingStop));
      expect(saving.onPressed, isNull);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.readingStart), findsOneWidget);
      expect(await inner.loadAll(), hasLength(1));
    });
  });
}
