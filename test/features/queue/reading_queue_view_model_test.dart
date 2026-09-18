import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/repositories/reading_queue_repository.dart';
import 'package:book_review_app/features/queue/data/hive_reading_queue_repository.dart';
import 'package:book_review_app/features/queue/presentation/viewmodel/reading_queue_view_model.dart';

Book book(String id, {ReadingStatus status = ReadingStatus.unread}) => Book(
      id: id,
      title: 'Title $id',
      author: 'Author $id',
      isbn: 'isbn-$id',
      readingStatus: status,
    );

void main() {
  final now = DateTime(2026, 9, 18);
  ReadingQueueEntry entry(String id, int pos) =>
      ReadingQueueEntry(bookId: id, position: pos, addedAt: now);

  late InMemoryReadingQueueRepository repo;
  final books = [book('a'), book('b'), book('c')];

  setUp(() {
    repo = InMemoryReadingQueueRepository();
  });

  group('load', () {
    test('キューと書籍一覧を読み込み、queue/nextToRead を公開する', () async {
      await repo.saveEntries([entry('b', 1), entry('a', 2)]);
      final vm = ReadingQueueViewModel(initialBooks: books);
      await vm.load(repo);
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
      expect(vm.queue.map((b) => b.id).toList(), ['b', 'a']);
      expect(vm.nextToRead?.id, 'b');
    });

    test('エントリが空なら nextToRead は null', () async {
      final vm = ReadingQueueViewModel(initialBooks: books);
      await vm.load(repo);
      expect(vm.queue, isEmpty);
      expect(vm.nextToRead, isNull);
    });

    test('リポジトリ例外時は errorMessage を設定', () async {
      final vm = ReadingQueueViewModel(initialBooks: books);
      final failing = _FailingRepository();
      await vm.load(failing);
      expect(vm.errorMessage, isNotNull);
      expect(vm.isLoading, isFalse);
      expect(vm.queue, isEmpty);
    });

    test('booksLoader による書籍取得（注入点）', () async {
      final vm = ReadingQueueViewModel(
        booksLoader: () async => [book('x')],
      );
      await vm.load(repo);
      await vm.add(repo, 'x');
      expect(vm.queue.single.id, 'x');
    });
  });

  group('add / remove / move', () {
    test('add で末尾追加され repository に永続化される', () async {
      final vm = ReadingQueueViewModel(initialBooks: books);
      await vm.load(repo);
      await vm.add(repo, 'b');
      await vm.add(repo, 'a');
      expect(vm.queue.map((b) => b.id).toList(), ['b', 'a']);
      final persisted = await repo.loadEntries();
      expect(persisted.map((e) => e.bookId).toList(), ['b', 'a']);
    });

    test('add の冪等性', () async {
      final vm = ReadingQueueViewModel(initialBooks: books);
      await vm.load(repo);
      await vm.add(repo, 'a');
      await vm.add(repo, 'a');
      expect(vm.queue.length, 1);
    });

    test('remove で除去される', () async {
      await repo.saveEntries([entry('a', 1), entry('b', 2)]);
      final vm = ReadingQueueViewModel(initialBooks: books);
      await vm.load(repo);
      await vm.remove(repo, 'a');
      expect(vm.queue.map((b) => b.id).toList(), ['b']);
    });

    test('moveUp / moveDown が永続化される', () async {
      await repo.saveEntries([entry('a', 1), entry('b', 2), entry('c', 3)]);
      final vm = ReadingQueueViewModel(initialBooks: books);
      await vm.load(repo);
      await vm.moveUp(repo, 'b');
      expect(vm.queue.map((b) => b.id).toList(), ['b', 'a', 'c']);
      await vm.moveDown(repo, 'b');
      expect(vm.queue.map((b) => b.id).toList(), ['a', 'b', 'c']);
      final persisted = await repo.loadEntries();
      expect(persisted.first.bookId, 'a');
    });
  });

  group('notifyListeners', () {
    test('load / add で通知される', () async {
      final vm = ReadingQueueViewModel(initialBooks: books);
      var notified = 0;
      vm.addListener(() => notified++);
      await vm.load(repo);
      await vm.add(repo, 'a');
      expect(notified, greaterThanOrEqualTo(2));
      vm.dispose();
    });
  });
}

class _FailingRepository implements ReadingQueueRepository {
  @override
  Future<List<ReadingQueueEntry>> loadEntries() async {
    throw StateError('boom');
  }

  @override
  Future<void> saveEntries(List<ReadingQueueEntry> entries) async {}
}
