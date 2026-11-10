// 共有ストレージ抽象の試練（book-review-app）。
//
// ここが緑でなければ「現世をまたぐ受け渡し」は実機で動かない。
// 実機（SAF）の 1 往復は別途。ここでは抽象の契約と、
// 「失敗を無音にしない」ことを固定する。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/infrastructure/shared_file_store.dart';
import 'package:book_review_app/core/logging/app_logger.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_event_exporter.dart';
import 'package:book_review_app/features/crossapp/domain/book_reward_event_service.dart';

/// メモリ上の [ISharedFileStore]。試練でフェイク注入する。
class _FakeSharedFileStore implements ISharedFileStore {
  final Map<String, String> files = <String, String>{};
  final List<String> appended = <String>[];
  bool ready = true;

  @override
  Future<bool> ensureDirectory() async => ready;

  @override
  Future<bool> chooseDirectory() async => ready;

  @override
  Future<void> writeString(String fileName, String content) async {
    files[fileName] = content;
  }

  @override
  Future<void> appendLine(String fileName, String line) async {
    appended.add('$fileName|$line');
    files[fileName] = '${files[fileName] ?? ''}$line\n';
  }

  @override
  Future<String?> readString(String fileName) async => files[fileName];

  @override
  Future<bool> delete(String fileName) async => files.remove(fileName) != null;

  @override
  Future<bool> exists(String fileName) async => files.containsKey(fileName);

  @override
  Future<List<String>> listFiles() async => files.keys.toList();
}

/// 必ず失敗する [ISharedFileStore]。無音にしていないことを確かめる。
class _FailingSharedFileStore implements ISharedFileStore {
  @override
  Future<bool> ensureDirectory() async => false;

  @override
  Future<bool> chooseDirectory() async => false;

  @override
  Future<void> writeString(String fileName, String content) async {
    throw SharedStorageException('write', fileName, 'disk full');
  }

  @override
  Future<void> appendLine(String fileName, String line) async {
    throw SharedStorageException('append', fileName, 'disk full');
  }

  @override
  Future<String?> readString(String fileName) async =>
      throw SharedStorageException('read', fileName, 'disk full');

  @override
  Future<bool> delete(String fileName) async => false;

  @override
  Future<bool> exists(String fileName) async => false;

  @override
  Future<List<String>> listFiles() async => const [];
}

Book _book() => Book(
      id: 'book-1',
      title: '坊っちゃん',
      author: '夏目漱石',
      isbn: '9784101010021',
      readingStatus: ReadingStatus.finished,
    );

Map<String, dynamic> _event() => const BookRewardEventService()
    .buildCompletionEvent(
      userId: 'user-1',
      book: _book(),
      completedCount: 1,
      eventId: 'evt-1',
      timestamp: DateTime.utc(2026, 5, 26, 1, 2, 3),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FileSharedFileStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('book_shared_store_');
    store = FileSharedFileStore(tempDir);
    SharedFileStore.reset();
  });

  tearDown(() {
    SharedFileStore.reset();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('契約: ファイル名', () {
    test('5現世で共有するファイル名が固定されている', () {
      expect(SharedCrossAppFiles.rpgEnemyDefeatJson,
          'rpg_enemy_defeat_events.json');
      expect(SharedCrossAppFiles.rpgEnemyDefeatJsonl,
          'rpg_enemy_defeat_events.jsonl');
      expect(SharedCrossAppFiles.tsundokuRewardEvents,
          'tsundoku_reward_events.jsonl');
      expect(SharedCrossAppFiles.tsundokuBookEvents, 'tsundoku_book_events.json');
      expect(SharedCrossAppFiles.tsundokuBookCompleted,
          'tsundoku_book_completed.json');
      expect(SharedCrossAppFiles.electionRewardEvents,
          'election_reward_events.jsonl');
      expect(SharedCrossAppFiles.bookReviewRewardEvents,
          'book_review_reward_events.jsonl');
      expect(SharedCrossAppFiles.kozuchiQuest, 'kozuchi_quest.json');
    });
  });

  group('FileSharedFileStore', () {
    test('writeString → readString で往復し、上書きされる', () async {
      expect(await store.ensureDirectory(), isTrue);
      await store.writeString('a.json', 'first');
      await store.writeString('a.json', 'second');
      expect(await store.readString('a.json'), 'second');
    });

    test('appendLine は1行ずつ追記する', () async {
      await store.appendLine('b.jsonl', 'line1');
      await store.appendLine('b.jsonl', 'line2');
      expect(await store.readString('b.jsonl'), 'line1\nline2\n');
    });

    test('存在しないファイルの readString は null・delete は false', () async {
      expect(await store.readString('none.json'), isNull);
      expect(await store.delete('none.json'), isFalse);
    });

    test('exists と listFiles が実ファイルを反映する', () async {
      await store.writeString('d.json', 'x');
      expect(await store.exists('d.json'), isTrue);
      expect(await store.listFiles(), contains('d.json'));
    });

    test('親ディレクトリが無くても writeString が自動で作る', () async {
      final nested = FileSharedFileStore(
        Directory('${tempDir.path}/nested/deep'),
      );
      await nested.writeString('e.json', 'x');
      expect(await nested.readString('e.json'), 'x');
    });
  });

  group('失敗を握りつぶさない（ファイル実装）', () {
    test('書けない場所では SharedStorageException を投げる', () async {
      final blocked = File('${tempDir.path}/blocked');
      await blocked.writeAsString('not a directory');
      final broken = FileSharedFileStore(Directory(blocked.path));

      await expectLater(
        broken.writeString('f.json', 'x'),
        throwsA(isA<SharedStorageException>()),
      );
    });

    test('例外は操作名とファイル名と原因を保持する', () async {
      final blocked = File('${tempDir.path}/blocked2');
      await blocked.writeAsString('not a directory');
      final broken = FileSharedFileStore(Directory(blocked.path));

      try {
        await broken.appendLine('g.jsonl', 'x');
        fail('例外が出るはず');
      } on SharedStorageException catch (e) {
        expect(e.operation, 'append');
        expect(e.fileName, 'g.jsonl');
        expect(e.cause, isNotNull);
      }
    });
  });

  group('AndroidSharedFileStore（MethodChannel 経由 = SAF）', () {
    late List<MethodCall> calls;
    final channel = const MethodChannel(
      'com.takamagahara.book_review_app/shared_storage',
    );

    void mock(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);
    }

    setUp(() => calls = <MethodCall>[]);

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('ensureDirectory が true なら appendLine が name/line を送る', () async {
      mock((call) async {
        calls.add(call);
        if (call.method == 'ensureDirectory') return true;
        return null;
      });

      final android = AndroidSharedFileStore();
      expect(await android.ensureDirectory(), isTrue);
      await android.appendLine(SharedCrossAppFiles.bookReviewRewardEvents, 'x');

      final append = calls.firstWhere((c) => c.method == 'appendLine');
      expect(append.arguments, {
        'name': SharedCrossAppFiles.bookReviewRewardEvents,
        'line': 'x',
      });
      // 2回目以降は ensureDirectory を再度叩かない（URI は永続化済み）
      expect(calls.where((c) => c.method == 'ensureDirectory'), hasLength(1));
    });

    test('ensureDirectory が false なら書込は SharedStorageException', () async {
      mock((call) async {
        if (call.method == 'ensureDirectory') return false;
        return null;
      });

      final android = AndroidSharedFileStore();
      await expectLater(
        android.appendLine('x.jsonl', 'line'),
        throwsA(
          isA<SharedStorageException>()
              .having((e) => e.operation, 'operation', 'append'),
        ),
      );
    });

    test('PlatformException は SharedStorageException に包んで伝える', () async {
      mock((call) async {
        if (call.method == 'ensureDirectory') return true;
        throw PlatformException(code: 'write_failed', message: 'boom');
      });

      final android = AndroidSharedFileStore();
      await expectLater(
        android.writeString('x.json', '{}'),
        throwsA(
          isA<SharedStorageException>()
              .having((e) => e.fileName, 'fileName', 'x.json')
              .having((e) => e.cause, 'cause', isA<PlatformException>()),
        ),
      );
    });

    test('readString と listFiles がチャネルの戻り値をそのまま返す', () async {
      mock((call) async {
        switch (call.method) {
          case 'ensureDirectory':
            return true;
          case 'readString':
            return '{"x":1}';
          case 'listFiles':
            return <String>['a.json', 'b.jsonl'];
        }
        return null;
      });

      final android = AndroidSharedFileStore();
      expect(await android.readString('a.json'), '{"x":1}');
      expect(await android.listFiles(), ['a.json', 'b.jsonl']);
    });

    test('プラグイン未実装（MissingPluginException）も例外として伝える', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      final android = AndroidSharedFileStore();
      await expectLater(
        android.ensureDirectory(),
        throwsA(isA<SharedStorageException>()),
      );
    });
  });

  group('SharedFileStore（全体で1つ）', () {
    test('configure した実装を instance が返す', () {
      SharedFileStore.configure(store);
      expect(SharedFileStore.instance, same(store));
      expect(SharedFileStore.isConfigured, isTrue);
    });

    test('未設定なら一時領域のファイル実装へフォールバックする', () {
      expect(SharedFileStore.instance, isA<FileSharedFileStore>());
      expect(SharedFileStore.isConfigured, isFalse);
    });

    test('reset で未設定に戻る', () {
      SharedFileStore.configure(store);
      SharedFileStore.reset();
      expect(SharedFileStore.isConfigured, isFalse);
    });
  });

  group('BookRewardEventExporter（共有ストア経由）', () {
    test('フェイク共有ストアへ book_review_reward_events.jsonl を追記する', () async {
      final fake = _FakeSharedFileStore();
      final exporter = BookRewardEventExporter(store: fake);

      expect(await exporter.append(_event()), isTrue);

      expect(fake.appended, hasLength(1));
      final entry = fake.appended.single;
      expect(entry.split('|').first, 'book_review_reward_events.jsonl');
      final decoded = jsonDecode(entry.split('|').last) as Map<String, dynamic>;
      expect(decoded['event_type'], 'book_completed');
      expect(decoded['event_id'], 'evt-1');
      expect(fake.files.containsKey('book_review_reward_events.jsonl'), isTrue);
    });

    test('SharedFileStore.instance が未設定でも本番経路はそこへ書く', () async {
      final fake = _FakeSharedFileStore();
      SharedFileStore.configure(fake);
      final exporter = const BookRewardEventExporter();

      expect(await exporter.append(_event()), isTrue);
      expect(fake.appended, hasLength(1));
    });

    test('共有ストアの失敗は SharedStorageException として上位へ伝わる', () async {
      final exporter = BookRewardEventExporter(store: _FailingSharedFileStore());

      await expectLater(
        exporter.append(_event()),
        throwsA(
          isA<SharedStorageException>()
              .having((e) => e.operation, 'operation', 'append')
              .having((e) => e.fileName, 'fileName',
                  'book_review_reward_events.jsonl'),
        ),
      );
    });

    test('明示パス経路の失敗は warn を1行残して false（無音にしない）', () async {
      final logs = <String>[];
      final blocked = File('${tempDir.path}/blocked_dir');
      await blocked.writeAsString('not a directory');

      final exporter = BookRewardEventExporter(
        filePath: '${blocked.path}/events.jsonl',
        logger: AppLogger(sink: logs.add),
      );

      expect(await exporter.append(_event()), isFalse);
      expect(logs, hasLength(1));
      expect(logs.single, contains('WARN'));
      expect(logs.single, contains('追記失敗'));
    });
  });
}
