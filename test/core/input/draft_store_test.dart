import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/input/draft_store.dart';

void main() {
  group('InMemoryDraftStore', () {
    test('書いた下書きを読み戻せる', () async {
      final store = InMemoryDraftStore();
      await store.write('review_new:book-1', '書きかけの本文');
      expect(await store.read('review_new:book-1'), '書きかけの本文');
    });

    test('未保存のキーは null', () async {
      final store = InMemoryDraftStore();
      expect(await store.read('unknown'), isNull);
    });

    test('clear で消える', () async {
      final store = InMemoryDraftStore();
      await store.write('k', 'v');
      await store.clear('k');
      expect(await store.read('k'), isNull);
    });

    test('空文字を書いたら消えたものとして扱う', () async {
      final store = InMemoryDraftStore();
      await store.write('k', 'v');
      await store.write('k', '   ');
      expect(await store.read('k'), isNull);
    });
  });

  group('HiveDraftStore（Hive 未初期化）', () {
    test('落ちずに null を返す（未処理エラーをゾーンへ漏らさない）', () async {
      final store = HiveDraftStore();
      expect(await store.read('k'), isNull);
      await store.write('k', 'v');
      expect(await store.read('k'), isNull);
      await store.clear('k');
    });
  });

  group('HiveDraftStore（箱を開けない＝I/O失敗）', () {
    test('落ちずに null を返す（下書きは最後の砦ゆえ例外を投げない）', () async {
      final store = HiveDraftStore(
        opener: (name) async => throw StateError('box unavailable'),
      );
      expect(await store.read('k'), isNull);
      await store.write('k', 'v');
      expect(await store.read('k'), isNull);
      await store.clear('k');
    });
  });

  group('HiveDraftStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_drafts_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('Hive に往復し、clear で消える', () async {
      final store = HiveDraftStore();
      await store.write('note_new:book-1', '引用の下書き');
      expect(await store.read('note_new:book-1'), '引用の下書き');

      await store.clear('note_new:book-1');
      expect(await store.read('note_new:book-1'), isNull);
    });

    test('別インスタンスからも読める（再起動相当）', () async {
      await HiveDraftStore().write('k', 'v');
      expect(await HiveDraftStore().read('k'), 'v');
    });
  });
}
