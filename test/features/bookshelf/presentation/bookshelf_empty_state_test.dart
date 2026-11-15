import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/widgets/empty_state.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';

/// 本棚の空状態（蔵書0件）が共通部品で描かれ、行動ボタンから既存導線
/// （バーコードスキャン）へ繋がることを撃つ試練。
void main() {
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_empty_state_test_');
    Hive.init(tempDir.path);
    repository = HiveBookRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await repository.close();
    await Hive.deleteBoxFromDisk('books');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('蔵書0件では共通部品の空状態と行動ボタンを出す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: BookshelfScreen(repository: repository)),
    );
    await tester.pump();

    // 既存文言は一字も変えていない。
    expect(find.text('📚 蔵書がありません'), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_empty_state')), findsOneWidget);
    expect(find.byKey(EmptyStateView.actionButtonKey), findsOneWidget);
    expect(find.text('本を追加'), findsOneWidget);
  });

  testWidgets('空状態の行動ボタンを押すと既存の追加導線へ遷移する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: BookshelfScreen(repository: repository)),
    );
    await tester.pump();

    await tester.tap(find.byKey(EmptyStateView.actionButtonKey));
    await tester.pumpAndSettle();

    // 既存の「本を追加」導線（バーコードスキャン画面）。
    expect(find.text('バーコードスキャン'), findsOneWidget);
  });

  testWidgets('蔵書があるときは空状態を出さない', (tester) async {
    // 空状態が出ないことの確認用（最小限の蔵書）。
    final book = Book(
      id: 'empty-state-check',
      title: '空状態ではない本',
      author: 'Author',
      isbn: 'empty-state-isbn',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BookshelfScreen(
          repository: repository,
          initialBooks: [book],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('bookshelf_empty_state')), findsNothing);
    expect(find.text('空状態ではない本'), findsOneWidget);
  });
}
