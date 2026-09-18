import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/queue/data/hive_reading_queue_repository.dart';
import 'package:book_review_app/features/queue/presentation/reading_queue_screen.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';

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

Book unreadBook(String id, String title) => Book(
      id: id,
      title: title,
      author: 'Author $id',
      isbn: 'isbn-$id',
    );

Book finishedBook(String id, String title) => Book(
      id: id,
      title: title,
      author: 'Author $id',
      isbn: 'isbn-$id',
      readingStatus: ReadingStatus.finished,
    );

void main() {
  group('本棚の導線', () {
    testWidgets('queueRepository 未指定なら導線を表示しない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(
            repository: FakeBookRepository([unreadBook('b1', '積読の本')]),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('reading_queue_button')), findsNothing);
    });

    testWidgets('queueRepository 指定時は導線を表示し、キュー画面へ遷移する', (tester) async {
      final queueRepository = InMemoryReadingQueueRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(
            repository: FakeBookRepository([unreadBook('b1', '積読の本')]),
            queueRepository: queueRepository,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('reading_queue_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reading_queue_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_reading_queue')), findsOneWidget);
    });
  });

  group('積読からの追加', () {
    testWidgets('FAB から候補を選ぶとキューに追加される', (tester) async {
      final repository = InMemoryReadingQueueRepository();
      final books = [
        unreadBook('b1', '一冊目'),
        unreadBook('b2', '二冊目'),
        finishedBook('b3', '読了済み'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingQueueScreen(repository: repository, books: books),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reading_queue_empty_state')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reading_queue_add_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reading_queue_candidate_sheet')),
          findsOneWidget);
      // 読了済みの本は候補に出ない
      expect(find.byKey(const Key('reading_queue_candidate_b3')), findsNothing);

      await tester.tap(find.byKey(const Key('reading_queue_candidate_b1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reading_queue_row_b1')), findsOneWidget);
      final saved = await repository.loadEntries();
      expect(saved.map((e) => e.bookId), ['b1']);
    });

    testWidgets('既にキューの本は候補に重複して出ない', (tester) async {
      final repository = InMemoryReadingQueueRepository();
      await repository.saveEntries([
        ReadingQueueEntry(
          bookId: 'b1',
          position: 1,
          addedAt: DateTime(2026, 9, 18),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingQueueScreen(
            repository: repository,
            books: [unreadBook('b1', '一冊目'), unreadBook('b2', '二冊目')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reading_queue_add_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reading_queue_candidate_b1')), findsNothing);
      expect(find.byKey(const Key('reading_queue_candidate_b2')), findsOneWidget);
    });

    testWidgets('候補が無いときは案内を表示する', (tester) async {
      final repository = InMemoryReadingQueueRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingQueueScreen(
            repository: repository,
            books: [finishedBook('b1', '読了済み')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reading_queue_add_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reading_queue_no_candidate')), findsOneWidget);
    });
  });
}
