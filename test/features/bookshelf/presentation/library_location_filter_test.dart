import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:book_review_app/features/bookshelf/presentation/library_filter_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('locations を渡すと所在チップが件数付きで表示される', (tester) async {
    await tester.pumpWidget(_wrap(LibraryFilterBar(
      query: const LibraryQuery(),
      totalCount: 10,
      filteredCount: 7,
      locations: const ['居間の本棚', '書斎の棚'],
      locationCounts: const {'居間の本棚': 3, '書斎の棚': 1},
      onChanged: (_) {},
    )));

    expect(find.byKey(const Key('library_location_chip_list')), findsOneWidget);
    expect(find.byKey(AppKeys.locationFilterChip('居間の本棚')), findsOneWidget);
    expect(find.byKey(AppKeys.locationFilterChip('書斎の棚')), findsOneWidget);
    expect(find.text('居間の本棚 (3)'), findsOneWidget);
    expect(find.text('書斎の棚 (1)'), findsOneWidget);
  });

  testWidgets('件数が無い所在はラベルのみ表示する', (tester) async {
    await tester.pumpWidget(_wrap(LibraryFilterBar(
      query: const LibraryQuery(),
      totalCount: 10,
      filteredCount: 7,
      locations: const ['屋根裏'],
      onChanged: (_) {},
    )));

    expect(find.text('屋根裏'), findsOneWidget);
  });

  testWidgets('チップをタップすると query.locations が変わる', (tester) async {
    LibraryQuery? captured;
    await tester.pumpWidget(_wrap(LibraryFilterBar(
      query: const LibraryQuery(),
      totalCount: 10,
      filteredCount: 7,
      locations: const ['居間の本棚', '書斎の棚'],
      onChanged: (q) => captured = q,
    )));

    await tester.tap(find.byKey(AppKeys.locationFilterChip('居間の本棚')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.locations, {'居間の本棚'});
    expect(captured!.genres, isEmpty);
  });

  testWidgets('選択済みチップを再タップすると locations から外れる', (tester) async {
    LibraryQuery? captured;
    await tester.pumpWidget(_wrap(LibraryFilterBar(
      query: const LibraryQuery(locations: {'居間の本棚', '書斎の棚'}),
      totalCount: 10,
      filteredCount: 7,
      locations: const ['居間の本棚', '書斎の棚'],
      onChanged: (q) => captured = q,
    )));

    await tester.tap(find.byKey(AppKeys.locationFilterChip('居間の本棚')));
    await tester.pumpAndSettle();

    expect(captured!.locations, {'書斎の棚'});
  });

  testWidgets('locations が空なら所在チップ列を表示しない', (tester) async {
    await tester.pumpWidget(_wrap(LibraryFilterBar(
      query: const LibraryQuery(),
      totalCount: 10,
      filteredCount: 7,
      onChanged: (_) {},
    )));

    expect(find.byKey(const Key('library_location_chip_list')), findsNothing);
  });
}
