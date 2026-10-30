import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';
import 'package:book_review_app/features/undo/presentation/undo_snack_bar.dart';

/// 読書時間の削除 → 「元に戻す」→ 復元 の合成試練。
void main() {
  final base = DateTime(2026, 10, 4, 12, 0);

  ReadingSession session(
    String id, {
    String? bookTitle,
    required DateTime startedAt,
    required int minutes,
  }) =>
      ReadingSession(
        id: id,
        bookTitle: bookTitle,
        startedAt: startedAt,
        durationMinutes: minutes,
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    InMemoryReadingSessionRepository repository,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingSessionScreen(repository: repository, now: () => base),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('読書時間 削除の元に戻す', () {
    testWidgets('削除直後に「元に戻す」SnackBar が出る', (tester) async {
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          bookTitle: '消える本',
          startedAt: base.subtract(const Duration(hours: 1)),
          minutes: 30));

      await pumpScreen(tester, repository);
      await tester.tap(find.byKey(const Key('reading_delete_s1')));
      await tester.pumpAndSettle();

      expect(repository.length, 0);
      expect(find.text('読書時間を削除しました'), findsOneWidget);
      expect(find.byKey(undoActionKey), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);
    });

    testWidgets('「元に戻す」タップで repository に復元され画面へ即反映される', (tester) async {
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          bookTitle: '復元される本',
          startedAt: base.subtract(const Duration(hours: 1)),
          minutes: 30));

      await pumpScreen(tester, repository);
      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reading_delete_s1')));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsNothing);

      await tester.tap(find.byKey(undoActionKey));
      await tester.pumpAndSettle();

      // repository に復元（id が保たれる）
      expect(repository.length, 1);
      final restored = (await repository.loadAll()).single;
      expect(restored.id, 's1');
      expect(restored.bookTitle, '復元される本');
      expect(restored.durationMinutes, 30);
      expect(restored.startedAt, base.subtract(const Duration(hours: 1)));

      // 画面の再読込経路が走り、行と統計が戻る
      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsOneWidget);
      expect(find.text('復元される本'), findsOneWidget);
      expect(find.text('30分'), findsNWidgets(2));
    });

    testWidgets('複数削除しても直前の1件だけが復元される（押し出し）', (tester) async {
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          bookTitle: '一冊目',
          startedAt: base.subtract(const Duration(hours: 2)),
          minutes: 30));
      await repository.add(session('s2',
          bookTitle: '二冊目',
          startedAt: base.subtract(const Duration(hours: 1)),
          minutes: 15));

      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('reading_delete_s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reading_delete_s2')));
      await tester.pumpAndSettle();

      expect(repository.length, 0);

      // 直近の SnackBar の「元に戻す」で復元されるのは s2 のみ
      await tester.tap(find.byKey(undoActionKey));
      await tester.pumpAndSettle();

      final restored = await repository.loadAll();
      expect(restored.map((s) => s.id).toList(), ['s2']);
      expect(find.byKey(AppKeys.readingSessionRow('s2')), findsOneWidget);
      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsNothing);
    });

    testWidgets('「元に戻す」は二重復元できない', (tester) async {
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          bookTitle: '一度きり',
          startedAt: base.subtract(const Duration(hours: 1)),
          minutes: 20));

      await pumpScreen(tester, repository);
      await tester.tap(find.byKey(const Key('reading_delete_s1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(undoActionKey));
      await tester.pumpAndSettle();

      // SnackBar は消費され、再度のアクションは存在しない
      expect(find.byKey(undoActionKey), findsNothing);
      expect(repository.length, 1);
    });
  });

  group('HiveReadingSessionRepository の id 保持（復元の前提）', () {
    final tempDir =
        Directory.systemTemp.createTempSync('reading_sessions_undo');
    late HiveReadingSessionRepository repository;

    setUp(() async {
      Hive.init(tempDir.path);
      repository = const HiveReadingSessionRepository();
      await repository.init();
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk(HiveReadingSessionRepository.boxName);
      await Hive.close();
    });

    test('remove → add で同じ id のまま復元される', () async {
      final original = session('hive-1',
          bookTitle: 'Hive本', startedAt: DateTime(2026, 10, 3, 9), minutes: 40);
      await repository.add(original);
      await repository.remove('hive-1');
      expect(await repository.loadAll(), isEmpty);

      await repository.add(original);

      final restored = (await repository.loadAll()).single;
      expect(restored.id, 'hive-1');
      expect(restored.bookTitle, 'Hive本');
      expect(restored.durationMinutes, 40);
      expect(restored.startedAt, DateTime(2026, 10, 3, 9));
    });
  });
}
