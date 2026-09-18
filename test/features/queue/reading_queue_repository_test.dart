import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/features/queue/data/hive_reading_queue_repository.dart';

void main() {
  group('InMemoryReadingQueueRepository', () {
    late InMemoryReadingQueueRepository repo;
    final now = DateTime(2026, 9, 18);

    setUp(() {
      repo = InMemoryReadingQueueRepository();
    });

    ReadingQueueEntry entry(String id, int pos) =>
        ReadingQueueEntry(bookId: id, position: pos, addedAt: now);

    test('保存→読み込みで値等価', () async {
      await repo.saveEntries([entry('a', 1), entry('b', 2)]);
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.bookId).toList(), ['a', 'b']);
    });

    test('上書き保存で以前の内容が消える', () async {
      await repo.saveEntries([entry('a', 1)]);
      await repo.saveEntries([entry('b', 1)]);
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.bookId).toList(), ['b']);
    });

    test('空リストの保存・読み込み', () async {
      await repo.saveEntries([]);
      expect(await repo.loadEntries(), isEmpty);
    });
  });

  group('HiveReadingQueueRepository', () {
    late HiveReadingQueueRepository repo;
    final now = DateTime(2026, 9, 18);

    setUpAll(() async {
      Hive.init('/tmp/hive_test_reading_queue');
    });

    setUp(() async {
      if (Hive.isBoxOpen('reading_queue_test')) {
        await Hive.deleteBoxFromDisk('reading_queue_test');
      }
      repo = HiveReadingQueueRepository();
      await repo.init(boxName: 'reading_queue_test');
    });

    tearDown(() async {
      await repo.close();
    });

    ReadingQueueEntry entry(String id, int pos) =>
        ReadingQueueEntry(bookId: id, position: pos, addedAt: now);

    test('保存→読み込みで値等価', () async {
      await repo.saveEntries([entry('a', 1), entry('b', 2)]);
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.bookId).toList(), ['a', 'b']);
      expect(loaded.map((e) => e.position).toList(), [1, 2]);
    });

    test('破損エントリは読み飛ばす', () async {
      await repo.saveEntries([entry('a', 1)]);
      final box = Hive.box<String>('reading_queue_test');
      await box.put('broken', 'not-json{{{');
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.bookId).toList(), ['a']);
    });

    test('clear で全消去', () async {
      await repo.saveEntries([entry('a', 1)]);
      await repo.clear();
      expect(await repo.loadEntries(), isEmpty);
    });
  });
}
