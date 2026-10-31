import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/state/load_state.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';

ReadingSession _session(
  String id, {
  required DateTime startedAt,
  int minutes = 30,
}) =>
    ReadingSession(
      id: id,
      bookTitle: '本-$id',
      startedAt: startedAt,
      durationMinutes: minutes,
    );

/// 呼び出しごとに挙動を切り替えるリポジトリ（試練用）。
class _ScriptedSessionRepository implements ReadingSessionRepository {
  _ScriptedSessionRepository(this.steps);

  final List<FutureOr<List<ReadingSession>> Function()> steps;
  int loadAllCalls = 0;

  @override
  Future<List<ReadingSession>> loadAll() async {
    final index =
        loadAllCalls < steps.length ? loadAllCalls : steps.length - 1;
    loadAllCalls++;
    return steps[index]();
  }

  @override
  Future<void> add(ReadingSession session) async {}

  @override
  Future<void> update(ReadingSession session) async {}

  @override
  Future<void> remove(String id) async {}
}

/// 再試行不能な失敗を返すリポジトリ。
class _BrokenSessionRepository
    implements ReadingSessionRepository, ReadingSessionLoadResultSource {
  @override
  Future<LoadResult<List<ReadingSession>>> tryLoadSessions() async =>
      LoadResult<List<ReadingSession>>.failure(
        '保存された読書記録の一部が壊れています',
        retryable: false,
        cause: const FormatException('broken'),
      );

  @override
  Future<List<ReadingSession>> loadAll() async =>
      throw StateError('呼ばれてはいけない');

  @override
  Future<void> add(ReadingSession session) async {}

  @override
  Future<void> update(ReadingSession session) async {}

  @override
  Future<void> remove(String id) async {}
}

void main() {
  final base = DateTime(2026, 10, 4, 12, 0);

  Future<void> pumpScreen(
    WidgetTester tester,
    ReadingSessionRepository repository,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingSessionScreen(
          repository: repository,
          now: () => base,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('読書時間画面: 失敗と0件の分離', () {
    testWidgets('読み込み失敗なら LoadErrorView を出し LoadEmptyView を出さない', (tester) async {
      final repository = _ScriptedSessionRepository([
        () => throw StateError('hive が壊れた'),
      ]);

      await pumpScreen(tester, repository);

      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_retry_button')), findsOneWidget);
      expect(find.text('読書セッションの読み込みに失敗しました'), findsOneWidget);
      // 既存の空状態文言が失敗時に漏れ出さない
      expect(find.text('まだ記録がありません'), findsNothing);
    });

    testWidgets('0件なら LoadEmptyView を出し LoadErrorView を出さない', (tester) async {
      final repository = _ScriptedSessionRepository([
        () => const <ReadingSession>[],
      ]);

      await pumpScreen(tester, repository);

      expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
      expect(find.text('まだ記録がありません'), findsOneWidget);
    });

    testWidgets('データがある成功時はどちらの状態も出さない', (tester) async {
      final repository = _ScriptedSessionRepository([
        () => [_session('s1', startedAt: base.subtract(const Duration(hours: 1)))],
      ]);

      await pumpScreen(tester, repository);

      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
      expect(find.text('30分'), findsNWidgets(2));
    });

    testWidgets('再試行タップで同じロードが2回目実行される', (tester) async {
      final repository = _ScriptedSessionRepository([
        () => throw StateError('1回目失敗'),
        () => throw StateError('2回目失敗'),
      ]);

      await pumpScreen(tester, repository);
      expect(repository.loadAllCalls, 1);

      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pumpAndSettle();

      expect(repository.loadAllCalls, 2);
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
    });

    testWidgets('再試行が成功すると LoadErrorView が消えてデータが出る', (tester) async {
      final repository = _ScriptedSessionRepository([
        () => throw StateError('一時的な失敗'),
        () => [_session('s1', startedAt: base.subtract(const Duration(hours: 1)))],
      ]);

      await pumpScreen(tester, repository);
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsOneWidget);
      expect(find.text('30分'), findsNWidgets(2));
    });

    testWidgets('失敗時は既存データを空にせず、空状態にも落ちない', (tester) async {
      final loaded = [
        _session('s1', startedAt: base.subtract(const Duration(hours: 1))),
      ];
      final repository = _ScriptedSessionRepository([
        () => loaded,
        () => throw StateError('再読込で失敗'),
        () => loaded,
      ]);

      await pumpScreen(tester, repository);
      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsOneWidget);

      // 2回目のロードを失敗させる（再試行を経由せず同じ失敗経路を通す）
      await tester.tap(find.byKey(AppKeys.readingAddButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reading_manual_minutes_field')),
        '10',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 失敗：空状態（0件）ではなくエラーとして扱う
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
      expect(find.text('まだ記録がありません'), findsNothing);

      // 再試行で同じデータが復帰する（失敗でデータを破棄していない）
      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsOneWidget);
      expect(find.text('30分'), findsNWidgets(2));
    });

    testWidgets('再試行不能な失敗では再試行ボタンを出さない', (tester) async {
      await pumpScreen(tester, _BrokenSessionRepository());

      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.text('保存された読書記録の一部が壊れています'), findsOneWidget);
      expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
    });
  });
}
