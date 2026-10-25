import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_event_exporter.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_export_coordinator.dart';
import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';

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

void main() {
  final now = DateTime.utc(2026, 10, 26, 12);

  /// 読書中（90/100）の本。
  const readingBook = Book(
    id: 'b1',
    title: '試験の書',
    author: '著者',
    isbn: '9784000000000',
    pageCount: 100,
    readingStatus: ReadingStatus.reading,
    currentPage: 90,
  );

  /// 蔵書詳細を pump する。書き出し行は [lines] に捕捉する。
  Future<void> pumpDetail(
    WidgetTester tester, {
    required _FakeBookRepository repository,
    required List<String> lines,
    required RewardExportLogRepository logRepository,
    Key? screenKey,
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final coordinator = BookRewardExportCoordinator(
      linkRepository: InMemoryCrossAppLinkRepository(userId: _userId),
      logRepository: logRepository,
      exporter: BookRewardEventExporter(
        lineWriter: (path, line) async => lines.add(line),
      ),
      eventIdGenerator: () => 'event-1',
      clock: () => now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailScreen(
          key: screenKey,
          book: readingBook,
          bookRepository: repository,
          reviewRepository: _FakeReviewRepository(),
          rewardExportCoordinator: coordinator,
          nowOverride: now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 「ページ更新」→ [page] 入力 → 保存。
  Future<void> enterPage(WidgetTester tester, String page) async {
    await tester.tap(find.byKey(AppKeys.bookProgressEdit));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.bookProgressInput), findsOneWidget);
    await tester.enterText(find.byKey(AppKeys.bookProgressInput), page);
    await tester.tap(find.byKey(AppKeys.bookProgressSave));
    await tester.pumpAndSettle();
  }

  group('蔵書詳細のページ更新からの読了書き出し', () {
    testWidgets('① ページ更新で読了に至ると book_completed が1行書き出される', (tester) async {
      final lines = <String>[];
      final repository = _FakeBookRepository([readingBook]);
      await pumpDetail(
        tester,
        repository: repository,
        lines: lines,
        logRepository: InMemoryRewardExportLogRepository(),
      );

      await enterPage(tester, '100');

      expect(lines, hasLength(1));
      final event = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(event['event_type'], 'book_completed');
      // rpg-task は metadata['count'] を int として読む
      final metadata = event['metadata'] as Map<String, dynamic>;
      expect(metadata['count'], isA<int>());
      // 今回の読了を含む冊数（保存前の一覧をそのまま渡すと 0 になる）
      expect(metadata['count'], 1);
      expect(metadata['book_id'], 'b1');
      // user_id はリンクコードで前方一致照合できる
      expect(event['user_id'], startsWith(_expectedCode));
    });

    testWidgets('② 読了に至らないページ更新では書き出されない', (tester) async {
      final lines = <String>[];
      final repository = _FakeBookRepository([readingBook]);
      await pumpDetail(
        tester,
        repository: repository,
        lines: lines,
        logRepository: InMemoryRewardExportLogRepository(),
      );

      await enterPage(tester, '95');

      expect(lines, isEmpty);
      expect(await repository.getBooks(), isNotEmpty);
    });

    testWidgets('③ 同じ本で再度 100 を入れても行は増えない（冪等）', (tester) async {
      final lines = <String>[];
      final logRepository = InMemoryRewardExportLogRepository();
      final repository = _FakeBookRepository([readingBook]);

      await pumpDetail(
        tester,
        repository: repository,
        lines: lines,
        logRepository: logRepository,
        screenKey: const ValueKey('first-visit'),
      );
      await enterPage(tester, '100');
      expect(lines, hasLength(1));

      // 同じ本を再度開いて（再入場・再送）読了にしても二重計上しない
      await pumpDetail(
        tester,
        repository: repository,
        lines: lines,
        logRepository: logRepository,
        screenKey: const ValueKey('second-visit'),
      );
      await enterPage(tester, '100');

      expect(lines, hasLength(1));
    });
  });
}
