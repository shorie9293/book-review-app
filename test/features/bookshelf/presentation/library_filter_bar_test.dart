import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:book_review_app/features/bookshelf/presentation/library_filter_bar.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  Finder chip(ReadingStatus s) => find.byKey(Key('library_status_chip_${s.name}'));

  Future<void> pump(WidgetTester tester, LibraryQuery query,
      ValueChanged<LibraryQuery> onChanged) async {
    await tester.pumpWidget(_wrap(LibraryFilterBar(
      query: query,
      totalCount: 10,
      filteredCount: 7,
      onChanged: onChanged,
    )));
  }

  testWidgets('検索フィールドに入力すると onChanged に反映される',
      (tester) async {
    LibraryQuery? captured;
    await pump(tester, const LibraryQuery(), (q) => captured = q);
    await tester.enterText(find.byKey(const Key('library_search_field')), '吾輩');
    expect(captured?.text, '吾輩');
  });

  testWidgets('読書状態チップをタップすると statuses に追加される', (tester) async {
    LibraryQuery? captured;
    await pump(tester, const LibraryQuery(), (q) => captured = q);
    await tester.tap(chip(ReadingStatus.unread));
    await tester.pump();
    expect(captured?.statuses, {ReadingStatus.unread});
  });

  testWidgets('選択済みチップは selected 状態で表示され、解除で statuses から外れる',
      (tester) async {
    LibraryQuery? captured;
    final selected = const LibraryQuery().copyWith(
      statuses: {ReadingStatus.unread},
    );
    await pump(tester, selected, (q) => captured = q);
    expect(tester.widget<FilterChip>(chip(ReadingStatus.unread)).selected,
        isTrue);
    expect(tester.widget<FilterChip>(chip(ReadingStatus.reading)).selected,
        isFalse);

    await tester.tap(chip(ReadingStatus.unread));
    await tester.pump();
    expect(captured?.statuses, isEmpty);
  });

  testWidgets('ソートボタンのポップアップメニューから並び替えを選べる', (tester) async {
    LibraryQuery? captured;
    await pump(tester, const LibraryQuery(), (q) => captured = q);
    await tester.tap(find.byKey(const Key('library_sort_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('書名（あ→ん）').last);
    await tester.pumpAndSettle();
    expect(captured?.sortOrder, LibrarySortOrder.titleAsc);
  });

  testWidgets('絞込が空のときリセットボタンは表示されない', (tester) async {
    await pump(tester, const LibraryQuery(), (_) {});
    expect(find.byKey(const Key('library_reset_button')), findsNothing);
  });

  testWidgets('絞込があるときリセットボタンが表示され、タップで既定に戻る', (tester) async {
    LibraryQuery? captured;
    final filtered = const LibraryQuery().copyWith(text: 'x');
    await pump(tester, filtered, (q) => captured = q);
    expect(find.byKey(const Key('library_reset_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('library_reset_button')));
    await tester.pump();
    expect(captured?.isDefault, isTrue);
  });

  testWidgets('件数表示が「絞込件数/全体件数」形式で表示される', (tester) async {
    await pump(tester, const LibraryQuery(), (_) {});
    expect(
      find.byKey(const Key('library_count_text')),
      findsOneWidget,
    );
    expect(find.textContaining('7'), findsWidgets);
    expect(find.textContaining('10'), findsWidgets);
  });
}
