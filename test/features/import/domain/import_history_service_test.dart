import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/import/domain/import_history_entry.dart';
import 'package:book_review_app/features/import/domain/import_history_service.dart';

ImportHistoryEntry entry({
  required String id,
  DateTime? importedAt,
  String mode = 'csv',
  int addedCount = 1,
  int skippedCount = 0,
  int notFoundCount = 0,
  int failedCount = 0,
}) {
  return ImportHistoryEntry(
    id: id,
    importedAt: importedAt ?? DateTime(2026, 5, 1),
    mode: mode,
    addedCount: addedCount,
    skippedCount: skippedCount,
    notFoundCount: notFoundCount,
    failedCount: failedCount,
    sampleIsbns: const [],
  );
}

void main() {
  group('append', () {
    test('新しい履歴を先頭に追加する', () {
      final history = [entry(id: 'a'), entry(id: 'b')];
      final result = ImportHistoryService.append(history, entry(id: 'c'));

      expect(result.map((e) => e.id), ['c', 'a', 'b']);
    });

    test('入力を破壊しない', () {
      final history = [entry(id: 'a'), entry(id: 'b')];
      final snapshot = List<ImportHistoryEntry>.from(history);

      ImportHistoryService.append(history, entry(id: 'c'));

      expect(history, snapshot);
      expect(history.length, 2);
    });

    test('maxEntries(200)を超えたら末尾から切り捨てる', () {
      final history = [
        for (var i = 0; i < ImportHistoryService.maxEntries; i++)
          entry(id: 'h$i')
      ];
      final result = ImportHistoryService.append(history, entry(id: 'newest'));

      expect(result.length, ImportHistoryService.maxEntries);
      expect(result.first.id, 'newest');
      expect(result.any((e) => e.id == 'h199'), isFalse, reason: '最古が落ちる');
      expect(result.last.id, 'h198');
    });

    test('同一idは置換し重複追加しない（先頭へ移動）', () {
      final history = [entry(id: 'a'), entry(id: 'b')];
      final result = ImportHistoryService.append(
        history,
        entry(id: 'b', addedCount: 9),
      );

      expect(result.length, 2);
      expect(result.map((e) => e.id), ['b', 'a']);
      expect(result.first.addedCount, 9);
    });

    test('空履歴にも追加できる', () {
      final result = ImportHistoryService.append(const [], entry(id: 'a'));
      expect(result.single.id, 'a');
    });
  });

  group('sortNewestFirst', () {
    test('importedAt降順に並べ、同時刻はid昇順でタイブレークする', () {
      final list = [
        entry(id: 'b', importedAt: DateTime(2026, 5, 2)),
        entry(id: 'old', importedAt: DateTime(2026, 4, 1)),
        entry(id: 'a', importedAt: DateTime(2026, 5, 2)),
      ];

      final sorted = ImportHistoryService.sortNewestFirst(list);

      expect(sorted.map((e) => e.id), ['a', 'b', 'old']);
    });

    test('入力を破壊しない', () {
      final list = [
        entry(id: 'a', importedAt: DateTime(2026, 1, 1)),
        entry(id: 'b', importedAt: DateTime(2026, 2, 1)),
      ];
      final snapshot = List<ImportHistoryEntry>.from(list);

      ImportHistoryService.sortNewestFirst(list);

      expect(list, snapshot);
    });
  });

  group('filterByMode', () {
    final list = [
      entry(id: 'a', mode: 'csv'),
      entry(id: 'b', mode: 'isbn'),
      entry(id: 'c', mode: 'csv'),
    ];

    test('nullは全件', () {
      expect(ImportHistoryService.filterByMode(list, null).length, 3);
    });

    test('空文字は全件', () {
      expect(ImportHistoryService.filterByMode(list, '').length, 3);
    });

    test('「すべて」は全件', () {
      expect(ImportHistoryService.filterByMode(list, 'すべて').length, 3);
    });

    test('モード一致のみ抽出し入力は破壊しない', () {
      final filtered = ImportHistoryService.filterByMode(list, 'csv');
      expect(filtered.map((e) => e.id), ['a', 'c']);
      expect(list.length, 3);
    });

    test('一致なしは空', () {
      expect(ImportHistoryService.filterByMode(list, 'unknown'), isEmpty);
    });
  });

  group('summarize', () {
    test('4カウントと実行回数を合計する', () {
      final summary = ImportHistoryService.summarize([
        entry(
            id: 'a',
            addedCount: 3,
            skippedCount: 1,
            notFoundCount: 0,
            failedCount: 0),
        entry(
            id: 'b',
            addedCount: 2,
            skippedCount: 0,
            notFoundCount: 4,
            failedCount: 1),
      ]);

      expect(summary.runs, 2);
      expect(summary.addedCount, 5);
      expect(summary.skippedCount, 1);
      expect(summary.notFoundCount, 4);
      expect(summary.failedCount, 1);
      expect(summary.totalCount, 11);
    });

    test('空履歴は全0', () {
      final summary = ImportHistoryService.summarize(const []);
      expect(summary.runs, 0);
      expect(summary.totalCount, 0);
    });
  });

  group('formatTimestamp', () {
    test('yyyy/MM/dd HH:mm で2桁ゼロ埋めする', () {
      expect(
        ImportHistoryService.formatTimestamp(DateTime(2026, 1, 5, 3, 7)),
        '2026/01/05 03:07',
      );
    });

    test('2桁月日・時刻はそのまま', () {
      expect(
        ImportHistoryService.formatTimestamp(DateTime(2026, 12, 31, 23, 59)),
        '2026/12/31 23:59',
      );
    });

    test('真夜中は00:00', () {
      expect(
        ImportHistoryService.formatTimestamp(DateTime(2026, 6, 1)),
        '2026/06/01 00:00',
      );
    });
  });
}
