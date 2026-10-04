import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/backup/presentation/backup_keys.dart';
import 'package:book_review_app/features/backup/presentation/backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book(String id) => Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
      addedAt: DateTime.utc(2026, 1, 1),
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 5,
      text: '良書',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ $id',
      createdAt: DateTime.utc(2026, 3, 3),
    );

BackupBundle _importBundle() => BackupBundle(
      exportedAt: DateTime.utc(2026, 4, 4),
      books: [
        Book(
          id: 'b-import',
          title: '輸入本',
          author: '著者',
          isbn: 'isbn-import',
          addedAt: DateTime.utc(2026, 1, 2),
        ),
      ],
      reviews: [
        Review(
          id: 'r1',
          bookId: 'b1',
          rating: 3,
          text: '既存重複',
          createdAt: DateTime.utc(2026, 2, 3),
        ),
      ],
      notes: [
        BookNote(
          id: 'n-import',
          bookId: 'b1',
          content: '輸入メモ',
          createdAt: DateTime.utc(2026, 3, 4),
        ),
      ],
    );

/// プラットフォームチャネルを触らないテスト用クリップボード。
class InMemoryClipboard {
  final List<String> written = [];
}

void main() {
  late InMemoryClipboard clipboard;
  late InMemoryBackupRepository repository;

  setUp(() {
    clipboard = InMemoryClipboard();
    repository = InMemoryBackupRepository(
      books: [_book('b1'), _book('b2')],
      reviews: [_review('r1', 'b1')],
      notes: [_note('n1', 'b1')],
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final written = clipboard.written;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          repository: repository,
          clipboardWriter: (value) async => written.add(value),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('①サマリー件数が表示される', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(BackupKeys.summaryCard), findsOneWidget);
    expect(find.text('蔵書 2冊 / レビュー 1件 / メモ 1件'), findsOneWidget);
  });

  testWidgets('②エクスポートで jsonPreview に JSON が出る', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(BackupKeys.exportButton));
    await tester.pumpAndSettle();

    final preview = tester.widget<SelectableText>(find.byWidgetPredicate(
      (w) => w is SelectableText && w.key == BackupKeys.jsonPreview,
    ));
    final text = preview.data ?? '';
    expect(text, contains('"schemaVersion"'));
    expect(text, contains('本 b1'));
  });

  testWidgets('③コピーボタンで writer に JSON が渡る', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(BackupKeys.exportButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BackupKeys.copyButton));
    await tester.pumpAndSettle();

    expect(clipboard.written, hasLength(1));
    expect(clipboard.written.single, contains('"schemaVersion"'));
  });

  testWidgets('④CSVボタンで writer に CSV が渡る', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(BackupKeys.csvExportButton));
    await tester.pumpAndSettle();

    expect(clipboard.written, hasLength(1));
    expect(clipboard.written.single, startsWith('id,title,author,isbn'));
  });

  testWidgets('⑤壊れたJSONの復元で errorText が出る', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byKey(BackupKeys.importField), '{broken json');
    await tester.ensureVisible(find.byKey(BackupKeys.restoreButton));
    await tester.tap(find.byKey(BackupKeys.restoreButton));
    await tester.pumpAndSettle();

    expect(find.byKey(BackupKeys.errorText), findsOneWidget);
    // 確認ダイアログは出てこない
    expect(find.byKey(BackupKeys.confirmRestoreButton), findsNothing);
  });

  testWidgets('⑥正しいJSONの復元で追加件数が表示され repository に反映される',
      (tester) async {
    await pumpScreen(tester);

    final incoming = const BackupService().exportJson(_importBundle());
    await tester.enterText(find.byKey(BackupKeys.importField), incoming);
    await tester.ensureVisible(find.byKey(BackupKeys.restoreButton));
    await tester.tap(find.byKey(BackupKeys.restoreButton));
    await tester.pumpAndSettle();

    // 確認ダイアログの復元ボタンを押す
    await tester.ensureVisible(find.byKey(BackupKeys.confirmRestoreButton));
    await tester.tap(find.byKey(BackupKeys.confirmRestoreButton));
    await tester.pumpAndSettle();

    // 追加 2件（本1・メモ1）、スキップ 1件（既存レビュー r1）
    expect(find.textContaining('追加 2件'), findsOneWidget);
    expect(find.textContaining('スキップ 1件'), findsOneWidget);
    expect(repository.books.map((b) => b.id), contains('b-import'));
    expect(repository.notes.map((n) => n.id), contains('n-import'));
    // サマリーが再読込される
    expect(find.text('蔵書 3冊 / レビュー 1件 / メモ 2件'), findsOneWidget);
  });
}
