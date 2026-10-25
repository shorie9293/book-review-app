import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/import/domain/bulk_import_parser.dart';
import 'package:book_review_app/features/import/domain/bulk_import_service.dart';
import 'package:book_review_app/features/import/domain/import_history_entry.dart';

ImportHistoryEntry entry({
  String id = 'h1',
  DateTime? importedAt,
  String mode = 'csv',
  int addedCount = 3,
  int skippedCount = 2,
  int notFoundCount = 1,
  int failedCount = 0,
  List<String> sampleIsbns = const ['9784774189079'],
}) {
  return ImportHistoryEntry(
    id: id,
    importedAt: importedAt ?? DateTime(2026, 5, 1, 10, 30),
    mode: mode,
    addedCount: addedCount,
    skippedCount: skippedCount,
    notFoundCount: notFoundCount,
    failedCount: failedCount,
    sampleIsbns: sampleIsbns,
  );
}

ImportEntry importEntry(String isbn, {int line = 1}) {
  return ImportEntry(
    raw: isbn,
    isbn: isbn,
    line: line,
    status: ImportEntryStatus.valid,
  );
}

void main() {
  group('ImportHistoryEntry 検証', () {
    test('空のidはArgumentError', () {
      expect(() => entry(id: ''), throwsArgumentError);
    });

    test('負のカウントはArgumentError', () {
      expect(() => entry(addedCount: -1), throwsArgumentError);
      expect(() => entry(skippedCount: -1), throwsArgumentError);
      expect(() => entry(notFoundCount: -1), throwsArgumentError);
      expect(() => entry(failedCount: -1), throwsArgumentError);
    });

    test('sampleIsbnsのnullはArgumentErrorにならず空リストへ正規化されない（明示不正）', () {
      // sampleIsbns は空リスト可（null 不可のため型で担保）
      final e = entry(sampleIsbns: const []);
      expect(e.sampleIsbns, isEmpty);
    });
  });

  group('ImportHistoryEntry 集計', () {
    test('totalCountは4カウントの合計、isEmptyは合計0でtrue', () {
      final e = entry(
          addedCount: 3, skippedCount: 2, notFoundCount: 1, failedCount: 4);
      expect(e.totalCount, 10);
      expect(e.isEmpty, isFalse);
      expect(
          entry(
                  addedCount: 0,
                  skippedCount: 0,
                  notFoundCount: 0,
                  failedCount: 0)
              .isEmpty,
          isTrue);
    });

    test('summaryLabelは4カウントを並べる', () {
      final e = entry(
          addedCount: 3, skippedCount: 2, notFoundCount: 1, failedCount: 0);
      expect(e.summaryLabel, '追加3 / 登録済2 / 書誌なし1 / 失敗0');
    });

    test('outcomeLabelは全0なら対象なし', () {
      final e = entry(
          addedCount: 0, skippedCount: 0, notFoundCount: 0, failedCount: 0);
      expect(e.outcomeLabel, '対象なし');
    });

    test('outcomeLabelは失敗>0なら一部失敗', () {
      final e = entry(
          addedCount: 2, skippedCount: 0, notFoundCount: 0, failedCount: 1);
      expect(e.outcomeLabel, '一部失敗');
    });

    test('outcomeLabelは失敗0なら完了', () {
      final e = entry(
          addedCount: 0, skippedCount: 5, notFoundCount: 2, failedCount: 0);
      expect(e.outcomeLabel, '完了');
    });
  });

  group('ImportHistoryEntry JSON', () {
    test('toJsonはDateTimeをISO8601文字列にする', () {
      final json = entry(importedAt: DateTime(2026, 5, 1, 10, 30)).toJson();
      expect(json['id'], 'h1');
      expect(json['importedAt'], isA<String>());
      expect(json['importedAt'], contains('2026-05-01T10:30'));
      expect(json['mode'], 'csv');
      expect(json['addedCount'], 3);
      expect(json['skippedCount'], 2);
      expect(json['notFoundCount'], 1);
      expect(json['failedCount'], 0);
      expect(json['sampleIsbns'], ['9784774189079']);
    });

    test('JSON往復で値等価になる', () {
      final original = entry(
        importedAt: DateTime.utc(2026, 5, 1, 1, 30),
        sampleIsbns: const ['9784774189079', '9784123456784'],
      );
      final restored = ImportHistoryEntry.fromJson(original.toJson());
      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
      expect(restored.importedAt, original.importedAt);
      expect(restored.sampleIsbns, original.sampleIsbns);
    });

    test('欠損キーはFormatException', () {
      final json = entry().toJson()..remove('id');
      expect(() => ImportHistoryEntry.fromJson(json), throwsFormatException);
    });

    test('型不正はFormatException', () {
      expect(
        () =>
            ImportHistoryEntry.fromJson(entry().toJson()..['addedCount'] = '3'),
        throwsFormatException,
      );
      expect(
        () => ImportHistoryEntry.fromJson(entry().toJson()..['id'] = 1),
        throwsFormatException,
      );
      expect(
        () => ImportHistoryEntry.fromJson(
            entry().toJson()..['sampleIsbns'] = ['a', 1]),
        throwsFormatException,
      );
    });

    test('日時文字列が不正ならFormatException', () {
      expect(
        () => ImportHistoryEntry.fromJson(
            entry().toJson()..['importedAt'] = 'not-a-date'),
        throwsFormatException,
      );
    });

    test('id空・負カウントのJSONもFormatException（検証違反の取り込み拒否）', () {
      expect(
        () => ImportHistoryEntry.fromJson(entry().toJson()..['id'] = ''),
        throwsFormatException,
      );
      expect(
        () =>
            ImportHistoryEntry.fromJson(entry().toJson()..['failedCount'] = -2),
        throwsFormatException,
      );
    });
  });

  group('buildImportHistoryEntry', () {
    test('reportから各カウントとサンプルISBNを取り出す', () {
      final report = BulkImportReport([
        ImportRecord(
            entry: importEntry('9784774189079', line: 1),
            outcome: ImportOutcome.added),
        ImportRecord(
            entry: importEntry('9784123456784', line: 2),
            outcome: ImportOutcome.added),
        ImportRecord(
            entry: importEntry('4123456782', line: 3),
            outcome: ImportOutcome.skippedExisting),
        ImportRecord(
            entry: importEntry('9784000000000', line: 4),
            outcome: ImportOutcome.notFound),
        ImportRecord(
            entry: importEntry('9784000000001', line: 5),
            outcome: ImportOutcome.failed),
      ]);

      final built = buildImportHistoryEntry(
        report: report,
        mode: 'csv',
        id: 'run-1',
        importedAt: DateTime(2026, 5, 2, 9, 0),
      );

      expect(built.id, 'run-1');
      expect(built.mode, 'csv');
      expect(built.importedAt, DateTime(2026, 5, 2, 9, 0));
      expect(built.addedCount, 2);
      expect(built.skippedCount, 1);
      expect(built.notFoundCount, 1);
      expect(built.failedCount, 1);
      expect(built.totalCount, 5);
      expect(built.sampleIsbns, [
        '9784774189079',
        '9784123456784',
        '4123456782',
        '9784000000000',
        '9784000000001',
      ]);
    });

    test('sampleIsbnsはmaxSamples件まで', () {
      final report = BulkImportReport([
        for (var i = 0; i < 8; i++)
          ImportRecord(
            entry: importEntry('978400000000$i', line: i + 1),
            outcome: ImportOutcome.added,
          ),
      ]);

      final built = buildImportHistoryEntry(
        report: report,
        mode: 'isbn',
        id: 'run-2',
        importedAt: DateTime(2026, 5, 2),
        maxSamples: 3,
      );

      expect(built.sampleIsbns.length, 3);
      expect(built.sampleIsbns.first, '9784000000000');
      expect(built.addedCount, 8);
    });

    test('空ISBNはサンプルから除外し、空レポートは空履歴相当になる', () {
      final report = BulkImportReport([
        ImportRecord(
            entry: importEntry('', line: 1), outcome: ImportOutcome.failed),
        ImportRecord(
            entry: importEntry('9784774189079', line: 2),
            outcome: ImportOutcome.added),
      ]);
      final built = buildImportHistoryEntry(
        report: report,
        mode: 'csv',
        id: 'run-3',
        importedAt: DateTime(2026, 5, 2),
      );
      expect(built.sampleIsbns, ['9784774189079']);
      expect(built.totalCount, 2);

      final empty = buildImportHistoryEntry(
        report: const BulkImportReport([]),
        mode: 'csv',
        id: 'run-4',
        importedAt: DateTime(2026, 5, 2),
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.sampleIsbns, isEmpty);
      expect(empty.outcomeLabel, '対象なし');
    });
  });
}
