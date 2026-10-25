import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_event_exporter.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_export_coordinator.dart';
import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';

Book _book({
  String id = 'book-1',
  ReadingStatus status = ReadingStatus.unread,
  DateTime? finishedAt,
}) {
  return Book(
    id: id,
    title: '草枕',
    author: '夏目漱石',
    isbn: '9784101010038',
    readingStatus: status,
    finishedAt: finishedAt,
  );
}

void main() {
  late List<String> lines;
  late InMemoryRewardExportLogRepository logRepo;
  late BookRewardEventExporter exporter;
  late DateTime fixedNow;

  setUp(() {
    lines = <String>[];
    logRepo = InMemoryRewardExportLogRepository();
    exporter = BookRewardEventExporter(
      filePath: '/tmp/test_book_review_events.jsonl',
      lineWriter: (_, line) async => lines.add(line),
    );
    fixedNow = DateTime.utc(2026, 5, 26, 15, 0, 0);
  });

  BookRewardExportCoordinator coordinatorWith(
    String? userId, {
    String Function()? eventIdGenerator,
  }) {
    return BookRewardExportCoordinator(
      linkRepository: InMemoryCrossAppLinkRepository(userId: userId),
      logRepository: logRepo,
      exporter: exporter,
      eventIdGenerator: eventIdGenerator ?? () => 'evt-fixed',
      clock: () => fixedNow,
    );
  }

  test('読了遷移で1行だけ書き出し、markSent に到達する', () async {
    final previous = _book();
    final updated = _book(status: ReadingStatus.finished, finishedAt: fixedNow);
    final allBooks = [updated, _book(id: 'book-2')];

    final ok = await coordinatorWith('user-abc').exportCompletion(
      previous: previous,
      updated: updated,
      allBooks: allBooks,
    );

    expect(ok, isTrue);
    expect(lines, hasLength(1));

    final decoded = jsonDecode(lines.single) as Map<String, dynamic>;
    expect(decoded['event_id'], 'evt-fixed');
    expect(decoded['event_type'], 'book_completed');
    expect(decoded['user_id'], 'user-abc');
    expect(decoded['timestamp'], fixedNow.toIso8601String());
    final metadata = decoded['metadata'] as Map<String, dynamic>;
    expect(metadata['count'], 1);
    expect(metadata['count'] is int, isTrue);
    expect(metadata['book_id'], 'book-1');
    expect(metadata['book_title'], '草枕');

    expect(
      await logRepo.loadSentKeys(),
      {'book-1|${fixedNow.toIso8601String()}'},
    );
  });

  test('2回目は再送しない（冪等）', () async {
    final previous = _book(status: ReadingStatus.reading);
    final updated = _book(status: ReadingStatus.finished, finishedAt: fixedNow);
    final coordinator = coordinatorWith('user-abc');

    expect(
      await coordinator.exportCompletion(
        previous: previous,
        updated: updated,
        allBooks: [updated],
      ),
      isTrue,
    );
    expect(
      await coordinator.exportCompletion(
        previous: previous,
        updated: updated,
        allBooks: [updated],
      ),
      isFalse,
    );
    expect(lines, hasLength(1));
  });

  test('非読了遷移では書き出さない', () async {
    final previous = _book();
    final updated = _book(status: ReadingStatus.reading);

    final ok = await coordinatorWith('user-abc').exportCompletion(
      previous: previous,
      updated: updated,
      allBooks: [updated],
    );

    expect(ok, isFalse);
    expect(lines, isEmpty);
    expect(await logRepo.loadSentKeys(), isEmpty);
  });

  test('userId 未確保（ensure が空文字）なら false で書き出さない', () async {
    final previous = _book();
    final updated = _book(status: ReadingStatus.finished, finishedAt: fixedNow);

    final coordinator = BookRewardExportCoordinator(
      linkRepository: const NoopCrossAppLinkRepository(),
      logRepository: logRepo,
      exporter: exporter,
      eventIdGenerator: () => 'evt-fixed',
      clock: () => fixedNow,
    );

    expect(
      await coordinator.exportCompletion(
        previous: previous,
        updated: updated,
        allBooks: [updated],
      ),
      isFalse,
    );
    expect(lines, isEmpty);
  });

  test('userId 未保存なら ensureUserId で生成して書き出す', () async {
    final previous = _book();
    final updated = _book(status: ReadingStatus.finished, finishedAt: fixedNow);

    final linkRepo = InMemoryCrossAppLinkRepository();
    final coordinator = BookRewardExportCoordinator(
      linkRepository: linkRepo,
      logRepository: logRepo,
      exporter: exporter,
      eventIdGenerator: () => 'evt-gen',
      clock: () => fixedNow,
    );

    expect(
      await coordinator.exportCompletion(
        previous: previous,
        updated: updated,
        allBooks: [updated],
      ),
      isTrue,
    );

    final userId = await linkRepo.loadUserId();
    expect(userId, isNotNull);
    expect((userId ?? '').isNotEmpty, isTrue);
    final decoded = jsonDecode(lines.single) as Map<String, dynamic>;
    expect(decoded['user_id'], userId);
  });

  test('追記失敗なら false で markSent しない', () async {
    final failing = BookRewardEventExporter(
      filePath: '/tmp/test_book_review_events.jsonl',
      lineWriter: (_, __) async => throw StateError('disk full'),
    );
    final previous = _book();
    final updated = _book(status: ReadingStatus.finished, finishedAt: fixedNow);

    final coordinator = BookRewardExportCoordinator(
      linkRepository: InMemoryCrossAppLinkRepository(userId: 'user-abc'),
      logRepository: logRepo,
      exporter: failing,
      eventIdGenerator: () => 'evt-fixed',
      clock: () => fixedNow,
    );

    expect(
      await coordinator.exportCompletion(
        previous: previous,
        updated: updated,
        allBooks: [updated],
      ),
      isFalse,
    );
    expect(await logRepo.loadSentKeys(), isEmpty);
  });

  test('リポジトリが例外を投げても外へ漏らさない', () async {
    final throwing = _ThrowingLinkRepository();
    final previous = _book();
    final updated = _book(status: ReadingStatus.finished, finishedAt: fixedNow);

    final coordinator = BookRewardExportCoordinator(
      linkRepository: throwing,
      logRepository: logRepo,
      exporter: exporter,
      clock: () => fixedNow,
    );

    expect(
      await coordinator.exportCompletion(
        previous: previous,
        updated: updated,
        allBooks: [updated],
      ),
      isFalse,
    );
    expect(lines, isEmpty);
  });

  test('既定の eventIdGenerator は uuid v4 を生成する', () async {
    final previous = _book();
    final updated = _book(status: ReadingStatus.finished, finishedAt: fixedNow);

    final coordinator = BookRewardExportCoordinator(
      linkRepository: InMemoryCrossAppLinkRepository(userId: 'user-abc'),
      logRepository: logRepo,
      exporter: exporter,
      clock: () => fixedNow,
    );

    expect(
      await coordinator.exportCompletion(
        previous: previous,
        updated: updated,
        allBooks: [updated],
      ),
      isTrue,
    );
    final decoded = jsonDecode(lines.single) as Map<String, dynamic>;
    final eventId = decoded['event_id'] as String;
    expect(eventId.length, 36);
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(eventId), isTrue);
    expect(eventId, isNot('evt-fixed'));
  });
}

class _ThrowingLinkRepository implements CrossAppLinkRepository {
  @override
  Future<String?> loadUserId() async => throw StateError('hive not ready');

  @override
  Future<String> ensureUserId() async => throw StateError('hive not ready');
}
