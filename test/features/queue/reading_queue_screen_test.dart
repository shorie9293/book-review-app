import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/repositories/reading_queue_repository.dart';
import 'package:book_review_app/features/queue/data/hive_reading_queue_repository.dart';
import 'package:book_review_app/features/queue/presentation/reading_queue_screen.dart';

Book book(String id, String title) => Book(
      id: id,
      title: title,
      author: 'Author $id',
      isbn: 'isbn-$id',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 9, 18);
  final books = [book('a', '宇宙の本'), book('b', '海の本'), book('c', '山の本')];

  ReadingQueueEntry entry(String id, int pos) =>
      ReadingQueueEntry(bookId: id, position: pos, addedAt: now);

  Future<void> pumpScreen(WidgetTester tester,
      {required ReadingQueueRepository repo, required List<Book> bookList}) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: ReadingQueueScreen(repository: repo, books: bookList),
      ),
    );
  }

  testWidgets('空のキューは empty state を表示する', (tester) async {
    await pumpScreen(
      tester,
      repo: InMemoryReadingQueueRepository(),
      bookList: books,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reading_queue_empty_state')), findsOneWidget);
    expect(find.byKey(const Key('reading_queue_next_card')), findsNothing);
  });

  testWidgets('次に読む一冊カードに先頭の本を表示する', (tester) async {
    final repo = InMemoryReadingQueueRepository();
    await repo.saveEntries([entry('a', 1), entry('b', 2)]);
    await pumpScreen(tester, repo: repo, bookList: books);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reading_queue_next_card')), findsOneWidget);
    expect(find.text('宇宙の本'), findsWidgets);
    expect(find.byKey(const Key('reading_queue_row_a')), findsOneWidget);
    expect(find.byKey(const Key('reading_queue_row_b')), findsOneWidget);
  });

  testWidgets('moveUp で行の順序が入れ替わる', (tester) async {
    final repo = InMemoryReadingQueueRepository();
    await repo.saveEntries([entry('a', 1), entry('b', 2), entry('c', 3)]);
    await pumpScreen(tester, repo: repo, bookList: books);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('reading_queue_row_b')),
      200,
    );
    await tester.pumpAndSettle();

    final downButtons = find.descendant(
      of: find.byKey(const Key('reading_queue_row_b')),
      matching: find.byKey(const Key('reading_queue_move_down_button')),
    );
    await tester.tap(downButtons.first);
    await tester.pumpAndSettle();

    // b が末尾へ移動し、永続化も反映されている
    final persisted = await repo.loadEntries();
    expect(persisted.last.bookId, 'b');
  });

  testWidgets('削除ボタンで行が消える', (tester) async {
    final repo = InMemoryReadingQueueRepository();
    await repo.saveEntries([entry('a', 1), entry('b', 2)]);
    await pumpScreen(tester, repo: repo, bookList: books);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reading_queue_remove_button')).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reading_queue_row_a')), findsNothing);
    expect(find.byKey(const Key('reading_queue_row_b')), findsOneWidget);
  });

  testWidgets('読了済みの本はキューに表示しない', (tester) async {
    final finishedBook = Book(
      id: 'c',
      title: '山の本',
      author: 'Author c',
      isbn: 'isbn-c',
      readingStatus: ReadingStatus.finished,
    );
    final repo = InMemoryReadingQueueRepository();
    await repo.saveEntries([entry('c', 1), entry('a', 2)]);
    await pumpScreen(tester, repo: repo, bookList: [book('a', '宇宙の本'), finishedBook]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reading_queue_row_c')), findsNothing);
    expect(find.byKey(const Key('reading_queue_row_a')), findsOneWidget);
  });
}
