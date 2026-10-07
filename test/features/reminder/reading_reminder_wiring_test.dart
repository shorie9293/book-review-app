import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/reminder/presentation/reading_reminder_settings_screen.dart';

/// テスト用のインメモリ書誌リポジトリ。
class FakeBookRepository implements BookRepository {
  FakeBookRepository(this._books);

  final List<Book> _books;

  @override
  Future<List<Book>> getBooks() async => List<Book>.from(_books);

  @override
  Future<Book?> getBookById(String id) async {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async => _books.add(book);

  @override
  Future<void> updateBook(Book book) async {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) _books[index] = book;
  }

  @override
  Future<void> removeBook(String id) async =>
      _books.removeWhere((book) => book.id == id);
}

void main() {
  group('本棚から読書リマインダー設定画面への導線', () {
    testWidgets('AppBar の導線をタップすると設定画面へ遷移する', (tester) async {
      final tempDir =
          Directory.systemTemp.createTempSync('reminder_wiring_hive');
      Hive.init(tempDir.path);
      addTearDown(() {
        try {
          Hive.deleteBoxFromDisk('reading_reminder_box');
        } catch (_) {}
        tempDir.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(
            repository: FakeBookRepository([
              const Book(
                id: 'b1',
                title: '積読の本',
                author: 'Author b1',
                isbn: 'isbn-b1',
              ),
            ]),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.readingReminderEntry));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(AppKeys.readingReminderScreen),
        findsOneWidget,
      );
      expect(
        find.byType(ReadingReminderSettingsScreen),
        findsOneWidget,
      );
    });
  });
}
