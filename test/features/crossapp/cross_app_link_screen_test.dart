import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';
import 'package:book_review_app/features/crossapp/presentation/cross_app_link_keys.dart';
import 'package:book_review_app/features/crossapp/presentation/cross_app_link_screen.dart';

/// userId は 36文字の uuid。連携コードは先頭8文字。
const String _userId = 'a1b2c3d4-1111-4222-8333-444455556666';
const String _expectedCode = 'a1b2c3d4';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    CrossAppLinkRepository? linkRepository,
    RewardExportLogRepository? logRepository,
    List<String>? clipboard,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CrossAppLinkScreen(
          linkRepository:
              linkRepository ?? InMemoryCrossAppLinkRepository(userId: _userId),
          logRepository: logRepository,
          clipboardWriter:
              clipboard == null ? null : (value) async => clipboard.add(value),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CrossAppLinkScreen', () {
    testWidgets('先頭8文字の連携コードが表示される', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(CrossAppLinkKeys.screen), findsOneWidget);
      expect(find.text('クロスアプリ連携'), findsWidgets);
      expect(find.text('連携コード'), findsOneWidget);

      final code = tester.widget<Text>(find.byKey(CrossAppLinkKeys.linkCode));
      expect(code.data, _expectedCode);
      expect(code.data!.length, 8);
    });

    testWidgets('コピーで clipboardWriter に8文字が渡り SnackBar が出る', (tester) async {
      final clipboard = <String>[];
      await pumpScreen(tester, clipboard: clipboard);

      await tester.tap(find.byKey(CrossAppLinkKeys.copyButton));
      await tester.pumpAndSettle();

      expect(clipboard, hasLength(1));
      expect(clipboard.single, _expectedCode);
      expect(clipboard.single.length, 8);
      expect(find.text('連携コードをコピーしました'), findsOneWidget);
    });

    testWidgets('logRepository 注入時は送信済み件数が出る', (tester) async {
      final logRepository = InMemoryRewardExportLogRepository();
      await logRepository.markSent('book-1|2026-01-01T00:00:00.000Z');
      await logRepository.markSent('book-2|2026-01-02T00:00:00.000Z');

      await pumpScreen(tester, logRepository: logRepository);

      expect(find.byKey(CrossAppLinkKeys.sentCount), findsOneWidget);
      expect(find.text('送信済みの読了イベント: 2件'), findsOneWidget);
    });

    testWidgets('logRepository 未注入時は件数行が出ない', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(CrossAppLinkKeys.sentCount), findsNothing);
      expect(find.textContaining('送信済みの読了イベント'), findsNothing);
    });
  });
}
