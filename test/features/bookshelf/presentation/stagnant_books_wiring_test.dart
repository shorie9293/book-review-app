import 'dart:io';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stagnant_wiring');
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

  testWidgets('本棚の停滞ボタンから停滞一覧へ遷移する', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: BookshelfScreen(
        repository: repository,
        initialBooks: [
          Book(
            id: 'stagnant-1',
            title: '積読の聖典',
            author: '著者',
            isbn: 'isbn-1',
            addedAt: DateTime.now().subtract(const Duration(days: 60)),
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    // 本棚自体は initialBooks を使うため追加本がロードされるまで進める
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('stagnant_books_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.stagnantEntry('stagnant-1')), findsOneWidget);
    expect(find.text('停滞している本'), findsWidgets);
  });
}