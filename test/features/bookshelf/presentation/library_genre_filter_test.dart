import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:book_review_app/features/bookshelf/presentation/library_filter_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> pumpBar(
  WidgetTester tester, {
  required LibraryQuery query,
  required ValueChanged<LibraryQuery> onChanged,
  List<String> genres = const [],
  Map<String, int> genreCounts = const {},
}) async {
  await tester.pumpWidget(_wrap(LibraryFilterBar(
    query: query,
    totalCount: 10,
    filteredCount: 7,
    genres: genres,
    genreCounts: genreCounts,
    onChanged: onChanged,
  )));
}

void main() {
  testWidgets('ジャンル0件ならジャンルチップ列は表示されない', (tester) async {
    await pumpBar(
      tester,
      query: const LibraryQuery(),
      onChanged: (_) {},
    );
    expect(find.byKey(const Key('library_genre_chip_list')), findsNothing);
    expect(find.byKey(AppKeys.genreFilterChip('小説')), findsNothing);
  });

  testWidgets('ジャンルチップに件数付きで表示される', (tester) async {
    await pumpBar(
      tester,
      query: const LibraryQuery(),
      onChanged: (_) {},
      genres: ['小説', '技術書'],
      genreCounts: {'小説': 3, '技術書': 1},
    );
    expect(find.byKey(AppKeys.genreFilterChip('小説')), findsOneWidget);
    expect(find.text('小説 (3)'), findsOneWidget);
    expect(find.text('技術書 (1)'), findsOneWidget);
  });

  testWidgets('チップをタップすると onChanged に genres が渡る', (tester) async {
    LibraryQuery? captured;
    await pumpBar(
      tester,
      query: const LibraryQuery(),
      onChanged: (q) => captured = q,
      genres: ['小説', '技術書'],
      genreCounts: {'小説': 3, '技術書': 1},
    );

    await tester.tap(find.byKey(AppKeys.genreFilterChip('小説')));
    await tester.pump();
    expect(captured?.genres, {'小説'});

    // このウィジェットは query を親が保持する制御コンポーネントのため、
    // 再タップは同じ初期状態から評価され、直前の選択は積み上がらない。
    await tester.tap(find.byKey(AppKeys.genreFilterChip('技術書')));
    await tester.pump();
    expect(captured?.genres, {'技術書'});
  });

  testWidgets('選択済みチップを再タップすると genres から外れる', (tester) async {
    LibraryQuery? captured;
    await pumpBar(
      tester,
      query: const LibraryQuery().copyWith(genres: {'小説'}),
      onChanged: (q) => captured = q,
      genres: ['小説'],
      genreCounts: {'小説': 3},
    );

    expect(
      tester
          .widget<FilterChip>(find.byKey(AppKeys.genreFilterChip('小説')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(AppKeys.genreFilterChip('小説')));
    await tester.pump();
    expect(captured?.genres, isEmpty);
    expect(captured?.activeFilterCount, 0);
  });
}
