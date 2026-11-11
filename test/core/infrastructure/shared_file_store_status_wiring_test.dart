// 共有ファイルストア ↔ 連携状態記録の配線の試練。
//
// 「共有フォルダへの書込／読取」が、そのまま画面に出る
// 「最終送信／最終受信」になることを固定する。
// 記録は unawaited で走るため、pumpEventQueue で追いつかせて観測する。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/infrastructure/cross_app_link_status.dart';
import 'package:book_review_app/core/infrastructure/cross_app_link_status_store.dart';
import 'package:book_review_app/core/infrastructure/shared_file_store.dart';

void main() {
  late Directory dir;
  late FileSharedFileStore store;

  CrossAppLinkSnapshot snapshot() => CrossAppLinkStatusRecorder.instance.cached;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('br_cross_app_link_');
    store = FileSharedFileStore(dir);
    CrossAppLinkStatusRecorder.reset(
      CrossAppLinkStatusRecorder(
        store: InMemoryCrossAppLinkStatusStore(),
        now: () => DateTime(2026, 11, 11, 9, 0),
      ),
    );
  });

  tearDown(() async {
    CrossAppLinkStatusRecorder.reset();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  test('writeString は送信1件として記録される', () async {
    await store.writeString('a.json', '{"x":1}');
    await pumpEventQueue();

    expect(snapshot().lastSent, isNotNull);
    expect(snapshot().lastSent!.ok, isTrue);
    expect(snapshot().lastSent!.count, 1);
    expect(snapshot().lastSent!.fileName, 'a.json');
    expect(snapshot().lastSent!.at, DateTime(2026, 11, 11, 9, 0));
    expect(snapshot().lastReceived, isNull);
  });

  test('appendLine も送信1件として記録される', () async {
    await store.appendLine('b.jsonl', '{"x":1}');
    await pumpEventQueue();

    expect(snapshot().lastSent!.ok, isTrue);
    expect(snapshot().lastSent!.count, 1);
    expect(snapshot().lastSent!.fileName, 'b.jsonl');
  });

  test('readString は受信として行数つきで記録される', () async {
    await store.writeString(
      'c.jsonl',
      '{"a":1}\n{"b":2}\n{"c":3}\n',
    );
    await pumpEventQueue();

    final content = await store.readString('c.jsonl');
    await pumpEventQueue();

    expect(content, isNotNull);
    expect(snapshot().lastReceived, isNotNull);
    expect(snapshot().lastReceived!.ok, isTrue);
    expect(snapshot().lastReceived!.count,
        CrossAppLinkStatusText.countLines(content));
    expect(snapshot().lastReceived!.count, 3);
    expect(snapshot().lastReceived!.fileName, 'c.jsonl');
  });

  test('存在しないファイルの readString は何も記録しない', () async {
    final content = await store.readString('missing.jsonl');
    await pumpEventQueue();

    expect(content, isNull);
    expect(snapshot().lastReceived, isNull);
    expect(snapshot().lastSent, isNull);
  });

  test('書込の失敗は送信失敗（ok=false）として記録される', () async {
    // ファイル名と同名のディレクトリを作り、書込を必ず失敗させる。
    await Directory('${dir.path}/blocked.jsonl').create();

    await expectLater(
      store.writeString('blocked.jsonl', 'x'),
      throwsA(isA<SharedStorageException>()),
    );
    await pumpEventQueue();

    expect(snapshot().lastSent, isNotNull);
    expect(snapshot().lastSent!.ok, isFalse);
    expect(snapshot().lastSent!.fileName, 'blocked.jsonl');
    expect(snapshot().lastSent!.error, isNotNull);
    expect(snapshot().lastSent!.error, isNotEmpty);
  });

  test('ensureDirectory は共有フォルダの状態を記録する', () async {
    expect(await store.ensureDirectory(), isTrue);
    await pumpEventQueue();

    expect(snapshot().sharedFolderReady, isTrue);
  });

  test('delete / exists / listFiles は送受信を記録しない', () async {
    await store.writeString('d.json', '{}');
    await pumpEventQueue();
    final before = snapshot().lastSent;

    await store.exists('d.json');
    await store.listFiles();
    await store.delete('d.json');
    await pumpEventQueue();

    expect(snapshot().lastSent!.at, before!.at);
    expect(snapshot().lastReceived, isNull);
  });
}
