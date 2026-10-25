import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/import/data/import_history_repository.dart';
import 'package:book_review_app/features/import/domain/import_history_entry.dart';
import 'package:book_review_app/features/import/domain/import_history_service.dart';
import 'package:book_review_app/features/import/presentation/import_history_screen.dart';

ImportHistoryEntry _entry({
  required String id,
  required DateTime importedAt,
  required String mode,
  int added = 0,
  int skipped = 0,
  int notFound = 0,
  int failed = 0,
  List<String> samples = const [],
}) {
  return ImportHistoryEntry(
    id: id,
    importedAt: importedAt,
    mode: mode,
    addedCount: added,
    skippedCount: skipped,
    notFoundCount: notFound,
    failedCount: failed,
    sampleIsbns: samples,
  );
}

void main() {
  final older = DateTime(2026, 3, 1, 9, 5);
  final newer = DateTime(2026, 5, 2, 18, 30);

  final entries = <ImportHistoryEntry>[
    _entry(
      id: 'old',
      importedAt: older,
      mode: 'CSV',
      added: 2,
      skipped: 1,
      samples: ['9784774189079'],
    ),
    _entry(
      id: 'new',
      importedAt: newer,
      mode: 'ISBNリスト',
      added: 3,
      notFound: 1,
      failed: 1,
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester,
    ImportHistoryRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ImportHistoryScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('履歴が空なら空状態を表示する', (tester) async {
    await pumpScreen(tester, InMemoryImportHistoryRepository());

    expect(find.byKey(const Key('screen_import_history')), findsOneWidget);
    expect(find.byKey(const Key('import_history_empty')), findsOneWidget);
    expect(find.text('取込履歴はまだありません'), findsOneWidget);
    expect(find.byKey(const Key('import_history_row_old')), findsNothing);
  });

  testWidgets('履歴を新しい順に一覧表示する', (tester) async {
    await pumpScreen(tester, InMemoryImportHistoryRepository(entries));

    expect(find.byKey(const Key('import_history_empty')), findsNothing);
    expect(find.byKey(const Key('import_history_row_old')), findsOneWidget);
    expect(find.byKey(const Key('import_history_row_new')), findsOneWidget);

    final newerY =
        tester.getTopLeft(find.byKey(const Key('import_history_row_new'))).dy;
    final olderY =
        tester.getTopLeft(find.byKey(const Key('import_history_row_old'))).dy;
    expect(newerY, lessThan(olderY));

    // 行には整形済み日時・モード・要約・結末が並ぶ
    expect(
        find.text(ImportHistoryService.formatTimestamp(older)), findsOneWidget);
    expect(find.textContaining('CSV'), findsWidgets);
    expect(find.textContaining(entries[0].summaryLabel), findsWidgets);
    expect(
      find.byKey(const Key('import_history_outcome_old')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('import_history_outcome_old')))
          .data,
      '完了',
    );
  });

  testWidgets('サマリーは ImportHistoryService.summarize の値と一致する', (tester) async {
    await pumpScreen(tester, InMemoryImportHistoryRepository(entries));

    final expected = ImportHistoryService.summarize(entries);

    String valueOf(String suffix) => tester
        .widget<Text>(find.byKey(Key('import_history_summary_$suffix')))
        .data!;

    expect(valueOf('runs'), '${expected.runs}');
    expect(valueOf('added'), '${expected.addedCount}');
    expect(valueOf('skipped'), '${expected.skippedCount}');
    expect(valueOf('not_found'), '${expected.notFoundCount}');
    expect(valueOf('failed'), '${expected.failedCount}');

    // 独自集計していないことの確認（合計値の突き合わせ）
    expect(expected.runs, 2);
    expect(expected.addedCount, 5);
    expect(expected.skippedCount, 1);
    expect(expected.notFoundCount, 1);
    expect(expected.failedCount, 1);
  });

  testWidgets('絞込チップでモードを切り替えられる', (tester) async {
    await pumpScreen(tester, InMemoryImportHistoryRepository(entries));

    expect(find.byKey(const Key('import_history_filter_all')), findsOneWidget);
    expect(find.byKey(const Key('import_history_filter_CSV')), findsOneWidget);
    expect(
      find.byKey(const Key('import_history_filter_ISBNリスト')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('import_history_filter_CSV')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import_history_row_old')), findsOneWidget);
    expect(find.byKey(const Key('import_history_row_new')), findsNothing);

    await tester.tap(find.byKey(const Key('import_history_filter_all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import_history_row_old')), findsOneWidget);
    expect(find.byKey(const Key('import_history_row_new')), findsOneWidget);
  });

  testWidgets('行タップで代表ISBNを含む詳細ダイアログを開く', (tester) async {
    await pumpScreen(tester, InMemoryImportHistoryRepository(entries));

    await tester.tap(find.byKey(const Key('import_history_row_old')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('import_history_detail_dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('import_history_detail_isbn_9784774189079')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('import_history_detail_close')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('import_history_detail_dialog')),
      findsNothing,
    );
  });
}
