import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:book_review_app/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';

const String _fileName = 'auto_backup_20261029.json';

Book _book(String id) => Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
      addedAt: DateTime.utc(2026, 1, 1),
    );

BackupBundle _bundle(List<Book> books) => BackupBundle(
      exportedAt: DateTime.utc(2026, 4, 4),
      books: books,
      reviews: const [],
      notes: const [],
    );

/// 設定スイッチを出す復元器（導線不変の確認用）。
class _OptionsRestorer implements AutoBackupRestorerWithOptions {
  final List<String> calls = [];
  bool? lastIncludeSettings;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) =>
      restoreWithOptions(fileName);

  @override
  Future<AutoBackupRestoreResult> restoreWithOptions(
    String fileName, {
    bool includeSettings = true,
  }) async {
    calls.add(fileName);
    lastIncludeSettings = includeSettings;
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

AutoBackupStore _storeWith(List<Book> books) {
  final store = InMemoryAutoBackupStore(now: () => DateTime(2026, 10, 29));
  store.seed(
    fileName: _fileName,
    createdAt: DateTime(2026, 10, 29, 7, 12),
    contents: const BackupService().exportJson(_bundle(books)),
  );
  return store;
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(AppKeys.autoBackupRestore(_fileName)));
    await tester.pumpAndSettle();
  }

  testWidgets('①世代復元の確認に内訳と先頭サンプルが出る', (tester) async {
    final store = _storeWith([_book('b1'), _book('b2'), _book('b3')]);
    final restorer = _OptionsRestorer();

    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: store,
        restorer: restorer,
        existingBundleLoader: () async => _bundle([_book('b1')]),
      ),
    ));
    await settle(tester);
    await openDialog(tester);

    final summary = tester.widget<Text>(
      find.byKey(AppKeys.autoBackupRestorePreviewSummary),
    );
    expect(summary.data, '追加 2件 / スキップ 1件');

    final breakdown = tester.widget<Text>(
      find.byKey(AppKeys.autoBackupRestorePreviewBreakdown),
    );
    expect(breakdown.data, contains('・蔵書: 追加 2冊 / 重複 1冊'));

    final samples = tester.widget<Text>(
      find.byKey(AppKeys.autoBackupRestorePreviewSamples),
    );
    expect(samples.data, contains('・蔵書「本 b2」'));
    expect(samples.data, contains('・蔵書「本 b3」'));

    // 既存優先（上書きしない）の一文
    expect(find.text('既存データは上書きされません（追加のみ行われます）'), findsOneWidget);
  });

  testWidgets('②内訳を足してもタイトル・スイッチ・Key は不変', (tester) async {
    final store = _storeWith([_book('b9')]);
    final restorer = _OptionsRestorer();

    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: store,
        restorer: restorer,
        existingBundleLoader: () async => _bundle(const []),
      ),
    ));
    await settle(tester);
    await openDialog(tester);

    expect(find.text('この世代を復元しますか？'), findsOneWidget);
    expect(
      find.byKey(AppKeys.autoBackupRestoreIncludeSettings),
      findsOneWidget,
    );
    expect(find.text('設定も戻す（テーマ・文字サイズ）'), findsOneWidget);
    expect(find.byKey(AppKeys.autoBackupRestoreCancel), findsOneWidget);
    expect(find.byKey(AppKeys.autoBackupRestoreConfirm), findsOneWidget);

    // スイッチは今までどおり効く
    await tester.tap(find.byKey(AppKeys.autoBackupRestoreIncludeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.autoBackupRestoreConfirm));
    await settle(tester);

    expect(restorer.calls, [_fileName]);
    expect(restorer.lastIncludeSettings, isFalse);
  });

  testWidgets('③採取失敗ならプレビューを出さず従来表示のまま', (tester) async {
    final store = _storeWith([_book('b1')]);
    final restorer = _OptionsRestorer();

    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: store,
        restorer: restorer,
        existingBundleLoader: () async => throw StateError('boom'),
      ),
    ));
    await settle(tester);
    await openDialog(tester);

    expect(find.byKey(AppKeys.autoBackupRestorePreviewSummary), findsNothing);
    expect(find.byKey(AppKeys.autoBackupRestorePreviewBreakdown), findsNothing);
    expect(find.byKey(AppKeys.autoBackupRestoreConfirm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('④JSON が復元できない世代ではプレビューを出さない', (tester) async {
    final store = InMemoryAutoBackupStore(now: () => DateTime(2026, 10, 29));
    store.seed(
      fileName: _fileName,
      createdAt: DateTime(2026, 10, 29, 7, 12),
      // 一覧には出るが BackupService.parse は通らない JSON
      contents: '{"schemaVersion":1}',
    );
    final restorer = _OptionsRestorer();

    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: store,
        restorer: restorer,
        existingBundleLoader: () async => _bundle([_book('b1')]),
      ),
    ));
    await settle(tester);
    await openDialog(tester);

    expect(find.byKey(AppKeys.autoBackupRestorePreviewSummary), findsNothing);
    expect(find.byKey(AppKeys.autoBackupRestoreConfirm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('⑤追加0件なら「追加されるデータはありません」', (tester) async {
    final store = _storeWith([_book('b1')]);
    final restorer = _OptionsRestorer();

    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: store,
        restorer: restorer,
        existingBundleLoader: () async => _bundle([_book('b1')]),
      ),
    ));
    await settle(tester);
    await openDialog(tester);

    final summary = tester.widget<Text>(
      find.byKey(AppKeys.autoBackupRestorePreviewSummary),
    );
    expect(summary.data, '追加 0件 / スキップ 1件');
    expect(find.textContaining('追加されるデータはありません'), findsOneWidget);
    expect(find.byKey(AppKeys.autoBackupRestorePreviewSamples), findsNothing);
  });

  testWidgets('⑥狭幅 360x640 でも復元確認が overflow しない', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _storeWith(
      List<Book>.generate(12, (i) => _book('w-$i')),
    );
    final restorer = _OptionsRestorer();

    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: store,
        restorer: restorer,
        existingBundleLoader: () async => _bundle(const []),
      ),
    ));
    await settle(tester);
    await openDialog(tester);

    expect(find.byKey(AppKeys.autoBackupRestorePreviewSummary), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
