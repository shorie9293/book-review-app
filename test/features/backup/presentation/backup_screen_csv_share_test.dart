import 'package:book_review_app/features/backup/data/backup_csv_sharer.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/presentation/backup_keys.dart';
import 'package:book_review_app/features/backup/presentation/backup_screen.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 共有呼び出しを記録するフェイク。
class _RecordingSharer implements BackupCsvSharer {
  final List<({String csv, String fileName})> calls = [];

  @override
  Future<void> share({required String csv, required String fileName}) async {
    calls.add((csv: csv, fileName: fileName));
  }
}

Book _book(String id) => Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
      addedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late InMemoryBackupRepository repository;

  setUp(() {
    repository = InMemoryBackupRepository(
      books: [_book('b1')],
      reviews: const [],
      notes: const [],
    );
  });

  Future<void> pumpScreen(WidgetTester tester, {BackupCsvSharer? sharer}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          repository: repository,
          clipboardWriter: (_) async {},
          csvSharer: sharer,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('「CSVを共有」タップで BOM 無し CSV と .csv ファイル名が渡る', (tester) async {
    final sharer = _RecordingSharer();
    await pumpScreen(tester, sharer: sharer);

    await tester.ensureVisible(find.byKey(BackupKeys.csvShareButton));
    await tester.tap(find.byKey(BackupKeys.csvShareButton));
    await tester.pumpAndSettle();

    expect(sharer.calls, hasLength(1));
    final call = sharer.calls.single;
    // BOM は sharer 層で付く契約なので、ここでは付いていないこと。
    expect(call.csv.contains('\uFEFF'), isFalse);
    expect(call.csv.startsWith('id,title,author,isbn'), isTrue);
    expect(call.fileName, endsWith('.csv'));
    expect(call.fileName, startsWith('book_backup_'));
  });

  testWidgets('csvSharer 未注入なら「CSVを共有」ボタンは存在しない', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(BackupKeys.csvShareButton), findsNothing);
    // 既存のクリップボード導線は温存されている。
    expect(find.byKey(BackupKeys.csvExportButton), findsOneWidget);
  });
}
