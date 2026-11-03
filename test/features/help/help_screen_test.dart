import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/help/domain/help_catalog.dart';
import 'package:book_review_app/features/help/domain/help_topic.dart';
import 'package:book_review_app/features/help/presentation/help_screen.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  group('HelpScreen', () {
    testWidgets('全トピックを表示する', (tester) async {
      await tester.pumpWidget(wrap(const HelpScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.helpScreen), findsOneWidget);
      expect(find.text('遊び方・ヘルプ'), findsOneWidget);
      expect(find.byKey(AppKeys.helpSearchField), findsOneWidget);

      for (final topic in HelpCatalog().allTopics) {
        expect(
          find.byKey(AppKeys.helpTopic(topic.id)),
          findsOneWidget,
          reason: 'missing topic: ${topic.id}',
        );
      }
    });

    testWidgets('検索で絞り込める', (tester) async {
      await tester.pumpWidget(wrap(const HelpScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.helpSearchField), 'レビュー');
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.helpTopic('page_tutorial_review')),
          findsOneWidget);
      expect(find.byKey(AppKeys.helpTopic('page_tutorial_bookshelf')),
          findsNothing);
      expect(find.byKey(AppKeys.helpEmpty), findsNothing);
    });

    testWidgets('0件なら空メッセージを出す', (tester) async {
      await tester.pumpWidget(wrap(const HelpScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(AppKeys.helpSearchField), '存在しない語句xyz');
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.helpEmpty), findsOneWidget);
      expect(find.textContaining('該当'), findsOneWidget);
      for (final topic in HelpCatalog().allTopics) {
        expect(find.byKey(AppKeys.helpTopic(topic.id)), findsNothing);
      }
    });

    testWidgets('検索語を消すと全件に戻る', (tester) async {
      await tester.pumpWidget(wrap(const HelpScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(AppKeys.helpSearchField), '存在しない語句xyz');
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.helpEmpty), findsOneWidget);

      await tester.enterText(find.byKey(AppKeys.helpSearchField), '');
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.helpEmpty), findsNothing);
      expect(find.byKey(AppKeys.helpTopic('page_tutorial_bookshelf')),
          findsOneWidget);
    });

    testWidgets('注入した catalog を使い、本文を展開して読める', (tester) async {
      const topic = HelpTopic(id: 'custom', title: '独自', body: '独自の本文');
      await tester.pumpWidget(wrap(HelpScreen(
        catalog: HelpCatalog(topics: const [topic]),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.helpTopic('custom')), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.helpTopic('custom')));
      await tester.pumpAndSettle();

      expect(find.text('独自の本文'), findsOneWidget);
    });
  });
}
