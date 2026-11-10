import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/backup/presentation/backup_keys.dart';
import 'package:book_review_app/features/backup/presentation/backup_screen.dart';

Book _book(String id, {String? title}) => Book(
      id: id,
      title: title ?? '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
      addedAt: DateTime.utc(2026, 1, 1),
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 5,
      text: 'レビュー $id',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ $id',
      createdAt: DateTime.utc(2026, 3, 3),
    );

BackupBundle _bundle({
  List<Book> books = const [],
  List<Review> reviews = const [],
  List<BookNote> notes = const [],
}) =>
    BackupBundle(
      exportedAt: DateTime.utc(2026, 4, 4),
      books: books,
      reviews: reviews,
      notes: notes,
    );

/// 初回だけ採取に成功し、以降は失敗するリポジトリ（プレビュー非表示の経路を突く）。
class _ThrowingCollectRepository implements BackupRepository {
  final InMemoryBackupRepository _delegate;
  int calls = 0;

  _ThrowingCollectRepository({required List<Book> books})
      : _delegate = InMemoryBackupRepository(
          books: books,
          reviews: const [],
          notes: const [],
        );

  @override
  Future<BackupBundle> collect() async {
    calls++;
    if (calls == 1) return _delegate.collect();
    throw StateError('collect failed');
  }

  @override
  Future<BackupMergeResult> restore(
    BackupBundle bundle, {
    bool includeSettings = true,
  }) async =>
      const BackupMergeResult(
        booksAdded: 0,
        reviewsAdded: 0,
        notesAdded: 0,
        booksSkipped: 0,
        reviewsSkipped: 0,
        notesSkipped: 0,
      );
}

void main() {
  late InMemoryBackupRepository repository;

  setUp(() {
    repository = InMemoryBackupRepository(
      books: [_book('b1'), _book('b2')],
      reviews: [_review('r1', 'b1')],
      notes: [_note('n1', 'b1')],
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    BackupRepository? repo,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          repository: repo ?? repository,
          clipboardWriter: (value) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRestoreDialog(WidgetTester tester, String json) async {
    await tester.enterText(find.byKey(BackupKeys.importField), json);
    await tester.ensureVisible(find.byKey(BackupKeys.restoreButton));
    await tester.tap(find.byKey(BackupKeys.restoreButton));
    await tester.pumpAndSettle();
  }

  testWidgets('①復元確認に内訳と追加対象の先頭サンプルが出る', (tester) async {
    await pumpScreen(tester);
    final json = const BackupService().exportJson(_bundle(
      books: [_book('b1'), _book('b9', title: '新刊')],
      reviews: [_review('r1', 'b1'), _review('r9', 'b9')],
      notes: [_note('n9', 'b9')],
    ));

    await openRestoreDialog(tester, json);

    final summary = tester.widget<Text>(
      find.byKey(BackupKeys.restorePreviewSummary),
    );
    expect(summary.data, '追加 3件 / スキップ 2件');

    final breakdown = tester.widget<Text>(
      find.byKey(BackupKeys.restorePreviewBreakdown),
    );
    expect(breakdown.data, contains('・蔵書: 追加 1冊 / 重複 1冊'));
    expect(breakdown.data, contains('・レビュー: 追加 1件 / 重複 1件'));
    expect(breakdown.data, contains('・メモ: 追加 1件 / 重複 0件'));

    final samples = tester.widget<Text>(
      find.byKey(BackupKeys.restorePreviewSamples),
    );
    expect(samples.data, contains('・蔵書「新刊」'));
    expect(samples.data, contains('・レビュー「レビュー r9」'));
    expect(samples.data, contains('・メモ「メモ n9」'));

    // 既存優先（上書きしない）の意味論が文言に出る
    expect(find.text('既存データは上書きされません（追加のみ行われます）'), findsOneWidget);
  });

  testWidgets('②破損JSONではダイアログを出さず、従来どおり errorText を出す', (tester) async {
    await pumpScreen(tester);

    await openRestoreDialog(tester, '{broken json');

    expect(find.byKey(BackupKeys.errorText), findsOneWidget);
    expect(find.byKey(BackupKeys.confirmRestoreButton), findsNothing);
    expect(find.byKey(BackupKeys.restorePreviewSummary), findsNothing);
  });

  testWidgets('③狭幅 360x640 でも復元確認が overflow しない', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester);
    final many = List<Book>.generate(12, (i) => _book('w-$i'));
    final json = const BackupService().exportJson(_bundle(books: many));

    await openRestoreDialog(tester, json);

    expect(find.byKey(BackupKeys.restorePreviewSummary), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('④確認ダイアログの導線（キャンセル／復元する）は不変', (tester) async {
    await pumpScreen(tester);
    final json = const BackupService().exportJson(
      _bundle(books: [_book('b9')]),
    );

    await openRestoreDialog(tester, json);

    expect(find.text('復元の確認'), findsOneWidget);
    expect(
      find.textContaining('既存のデータは上書きされません。よろしいですか？'),
      findsOneWidget,
    );
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.byKey(BackupKeys.confirmRestoreButton), findsOneWidget);

    await tester.ensureVisible(find.byKey(BackupKeys.confirmRestoreButton));
    await tester.tap(find.byKey(BackupKeys.confirmRestoreButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('復元完了: 追加 1件'), findsOneWidget);
    expect(repository.books.map((b) => b.id), contains('b9'));
  });

  testWidgets('⑤追加0件なら「追加されるデータはありません」を出し、導線は残る', (tester) async {
    await pumpScreen(tester);
    // 既存と完全一致（全件重複）のバックアップ
    final json = const BackupService().exportJson(_bundle(
      books: [_book('b1'), _book('b2')],
      reviews: [_review('r1', 'b1')],
      notes: [_note('n1', 'b1')],
    ));

    await openRestoreDialog(tester, json);

    final summary = tester.widget<Text>(
      find.byKey(BackupKeys.restorePreviewSummary),
    );
    expect(summary.data, '追加 0件 / スキップ 4件');
    expect(find.textContaining('追加されるデータはありません'), findsOneWidget);
    expect(find.byKey(BackupKeys.restorePreviewSamples), findsNothing);
    expect(find.byKey(BackupKeys.confirmRestoreButton), findsOneWidget);
  });

  testWidgets('⑥現状の採取に失敗したらプレビューを出さず従来表示のまま', (tester) async {
    await pumpScreen(
      tester,
      repo: _ThrowingCollectRepository(books: [_book('b1')]),
    );
    final json = const BackupService().exportJson(
      _bundle(books: [_book('b9')]),
    );

    await openRestoreDialog(tester, json);

    // ダイアログ自体と従来文言は出る
    expect(find.text('復元の確認'), findsOneWidget);
    expect(find.textContaining('を復元します。'), findsOneWidget);
    expect(find.byKey(BackupKeys.restorePreviewSummary), findsNothing);
    expect(find.byKey(BackupKeys.confirmRestoreButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
