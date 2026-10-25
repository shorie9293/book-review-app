import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/backup/presentation/backup_screen.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_event_exporter.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_export_coordinator.dart';
import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';
import 'package:book_review_app/features/crossapp/presentation/cross_app_link_keys.dart';
import 'package:book_review_app/features/crossapp/presentation/cross_app_link_screen.dart';

const String _userId = 'abcd1234-9999-4aaa-8bbb-ccccddddeeee';
const String _expectedCode = 'abcd1234';

/// 試練用の書庫（Hive を使わない）。
class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(List<Book> books) : _books = List<Book>.of(books);

  final List<Book> _books;

  @override
  Future<List<Book>> getBooks() async => List<Book>.of(_books);

  @override
  Future<Book?> getBookById(String id) async {
    for (final b in _books) {
      if (b.id == id) return b;
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
      _books.removeWhere((b) => b.id == id);
}

class _FakeReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => const [];

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

class _FakeNoteRepository implements BookNoteRepository {
  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async => const [];

  @override
  Future<List<BookNote>> getAllNotes() async => const [];

  @override
  Future<void> addNote(BookNote note) async {}

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> deleteNotesByBookId(String bookId) async {}
}

void main() {
  final now = DateTime.utc(2026, 10, 26, 12);

  Book book(String id) => Book(
        id: id,
        title: '本 $id',
        author: '著者',
        isbn: 'isbn-$id',
      );

  /// 本棚を pump する。書き出し行は [lines] に捕捉する。
  Future<void> pumpBookshelf(
    WidgetTester tester, {
    required List<Book> books,
    required List<String> lines,
    CrossAppLinkRepository? linkRepository,
    RewardExportLogRepository? logRepository,
    bool withBackupEntry = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeBookRepository(books);
    final linkRepo =
        linkRepository ?? InMemoryCrossAppLinkRepository(userId: _userId);
    final coordinator = BookRewardExportCoordinator(
      linkRepository: linkRepo,
      logRepository: logRepository ?? InMemoryRewardExportLogRepository(),
      exporter: BookRewardEventExporter(
        lineWriter: (path, line) async => lines.add(line),
      ),
      eventIdGenerator: () => 'event-1',
      clock: () => now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BookshelfScreen(
          repository: repository,
          initialBooks: books,
          reviewRepository: withBackupEntry ? _FakeReviewRepository() : null,
          noteRepository: withBackupEntry ? _FakeNoteRepository() : null,
          crossAppLinkRepository: withBackupEntry ? linkRepo : null,
          crossAppRewardLogRepository: withBackupEntry ? logRepository : null,
          rewardExportCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 本の状態ボタン → 「読了」を選ぶ。
  Future<void> markFinished(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(Key('status_button_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('status_option_finished')));
    await tester.pumpAndSettle();
  }

  group('クロスアプリ連携の合成', () {
    testWidgets('① 読了にすると book_completed が1行書き出される', (tester) async {
      final lines = <String>[];
      await pumpBookshelf(tester, books: [book('b1')], lines: lines);

      await markFinished(tester, 'b1');

      expect(lines, hasLength(1));
      final event = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(event['event_type'], 'book_completed');
      expect(event['user_id'], _userId);
      // rpg-task は metadata['count'] を int として読む
      final metadata = event['metadata'] as Map<String, dynamic>;
      expect(metadata['count'], isA<int>());
      expect(metadata['count'], 1);
      expect(metadata['book_id'], 'b1');
      // user_id はリンクコードで前方一致照合できる
      expect(event['user_id'].toString().substring(0, 8), _expectedCode);
    });

    testWidgets('② 同じ本をもう一度「読了」にしても行は増えない（冪等）', (tester) async {
      final lines = <String>[];
      await pumpBookshelf(tester, books: [book('b1')], lines: lines);

      await markFinished(tester, 'b1');
      expect(lines, hasLength(1));

      await markFinished(tester, 'b1');
      expect(lines, hasLength(1));
    });

    testWidgets('③ 「読書中」への変更では書き出されない', (tester) async {
      final lines = <String>[];
      await pumpBookshelf(tester, books: [book('b2')], lines: lines);

      await tester.tap(find.byKey(const Key('status_button_b2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('status_option_reading')));
      await tester.pumpAndSettle();

      expect(lines, isEmpty);
    });

    testWidgets('④ バックアップ画面の導線から連携画面へ遷移し同じコードが出る', (tester) async {
      final lines = <String>[];
      await pumpBookshelf(
        tester,
        books: [book('b3')],
        lines: lines,
        withBackupEntry: true,
      );

      await tester.tap(find.byKey(const Key('backup_button')));
      await tester.pumpAndSettle();

      expect(find.byType(BackupScreen), findsOneWidget);
      final entry = find.byKey(CrossAppLinkKeys.entry);
      expect(entry, findsOneWidget);

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(CrossAppLinkScreen), findsOneWidget);
      final code =
          tester.widget<Text>(find.byKey(CrossAppLinkKeys.linkCode)).data;
      expect(code, _expectedCode);
    });
  });
}
