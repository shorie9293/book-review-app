import 'package:book_review_app/core/search/search_history_chips.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('履歴が空なら何も描画しない', (tester) async {
    await tester.pumpWidget(_wrap(SearchHistoryChips(
      entries: const [],
      onSelected: (_) {},
    )));

    expect(find.byType(ActionChip), findsNothing);
    expect(find.byKey(AppKeys.librarySearchHistoryChips), findsNothing);
  });

  testWidgets('履歴を新しい順のままチップとして並べる', (tester) async {
    await tester.pumpWidget(_wrap(SearchHistoryChips(
      entries: const ['吾輩は猫である', '夏目漱石'],
      onSelected: (_) {},
    )));

    final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
    expect(chips.length, 2);
    expect(find.byKey(AppKeys.librarySearchHistoryChip('吾輩は猫である')),
        findsOneWidget);
    expect(
        find.byKey(AppKeys.librarySearchHistoryChip('夏目漱石')), findsOneWidget);
    // 先頭が最新語
    final first = tester
        .getTopLeft(find.byKey(AppKeys.librarySearchHistoryChip('吾輩は猫である')));
    final second =
        tester.getTopLeft(find.byKey(AppKeys.librarySearchHistoryChip('夏目漱石')));
    expect(first.dx, lessThan(second.dx));
  });

  testWidgets('チップをタップすると検索語が通知される', (tester) async {
    String? selected;
    await tester.pumpWidget(_wrap(SearchHistoryChips(
      entries: const ['草枕'],
      onSelected: (value) => selected = value,
    )));

    await tester.tap(find.byKey(AppKeys.librarySearchHistoryChip('草枕')));
    await tester.pump();

    expect(selected, '草枕');
  });
}
