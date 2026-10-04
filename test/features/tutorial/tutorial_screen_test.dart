import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/tutorial/data/tutorial_repository.dart';
import 'package:book_review_app/features/tutorial/domain/tutorial_step.dart';
import 'package:book_review_app/features/tutorial/presentation/tutorial_content.dart';
import 'package:book_review_app/features/tutorial/presentation/tutorial_screen.dart';
import 'package:book_review_app/features/tutorial/presentation/widgets/tutorial_page.dart';

void main() {
  Widget buildHost(Widget child) => MaterialApp(home: child);

  testWidgets('初回（未完了）はチュートリアル画面が表示される', (tester) async {
    await tester.pumpWidget(buildHost(
      TutorialScreen(repository: InMemoryTutorialRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.tutorialScreen), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  test('TutorialContent は TutorialStep 宣言順の5ページを生成する', () {
    expect(TutorialContent.pageCount, TutorialStep.values.length);
    for (var i = 0; i < TutorialStep.values.length; i++) {
      final step = TutorialStep.values[i];
      final page = TutorialContent.pages[i];
      expect(page.keyName, 'page_tutorial_${step.name}');
      expect(page.title, step.label);
      expect(page.body, step.description);
    }
  });

  testWidgets('ページの内容（アイコン・見出し・本文）が表示される', (tester) async {
    await tester.pumpWidget(buildHost(
      TutorialScreen(repository: InMemoryTutorialRepository()),
    ));
    await tester.pumpAndSettle();

    final first = TutorialContent.pages.first;
    expect(find.byKey(AppKeys.tutorialPage(first.keyName)), findsOneWidget);
    expect(find.byIcon(first.icon), findsOneWidget);
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(first.body), findsOneWidget);
  });

  testWidgets('「次へ」タップでページ送りされ、インジケータが変化する', (tester) async {
    await tester.pumpWidget(buildHost(
      TutorialScreen(repository: InMemoryTutorialRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 / ${TutorialContent.pageCount}'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.tutorialNext));
    await tester.pumpAndSettle();

    expect(find.text('2 / ${TutorialContent.pageCount}'), findsOneWidget);
  });

  testWidgets('「スキップ」で markCompleted が呼ばれ onFinished が発火する', (tester) async {
    final repo = InMemoryTutorialRepository();
    var finished = false;
    await tester.pumpWidget(buildHost(
      TutorialScreen(
        repository: repo,
        onFinished: () => finished = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.tutorialSkip));
    await tester.pumpAndSettle();

    expect(await repo.isCompleted(), isTrue);
    expect(finished, isTrue);
  });

  testWidgets('最終ページでは「はじめる」ボタンになり、タップで完了する', (tester) async {
    final repo = InMemoryTutorialRepository();
    var finished = false;
    await tester.pumpWidget(buildHost(
      TutorialScreen(
        repository: repo,
        onFinished: () => finished = true,
      ),
    ));
    await tester.pumpAndSettle();

    // 最終ページまで送る
    for (var i = 0; i < TutorialContent.pageCount - 1; i++) {
      await tester.tap(find.byKey(AppKeys.tutorialNext));
      await tester.pumpAndSettle();
    }

    expect(find.text('はじめる'), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.tutorialNext));
    await tester.pumpAndSettle();

    expect(await repo.isCompleted(), isTrue);
    expect(finished, isTrue);
  });

  testWidgets('pages を注入するとそのページ数が反映される', (tester) async {
    final pages = [
      const TutorialPageData(
        keyName: 'page_custom_a',
        icon: Icons.menu_book,
        title: 'カスタムA',
        body: '説明A',
      ),
      const TutorialPageData(
        keyName: 'page_custom_b',
        icon: Icons.favorite,
        title: 'カスタムB',
        body: '説明B',
      ),
    ];
    await tester.pumpWidget(buildHost(
      TutorialScreen(
        repository: InMemoryTutorialRepository(),
        pages: pages,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('カスタムA'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.tutorialNext));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    // 2ページなら最終ページで「はじめる」
    expect(find.text('はじめる'), findsOneWidget);
  });

  testWidgets('TutorialPageView 単体でデータを表示する', (tester) async {
    const data = TutorialPageData(
      keyName: 'page_unit',
      icon: Icons.auto_stories,
      title: '単体見出し',
      body: '単体本文',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TutorialPageView(data: data)),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    expect(find.text('単体見出し'), findsOneWidget);
    expect(find.text('単体本文'), findsOneWidget);
  });
}
