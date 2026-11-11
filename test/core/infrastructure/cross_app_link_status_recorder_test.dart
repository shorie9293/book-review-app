// 連携状態の記録口（CrossAppLinkStatusRecorder）の試練。
//
// 記録は「本処理の邪魔をしない」ことが最大の要件:
// 保存が失敗しても throw せず、同時送信でも取りこぼさず、
// 初回記録で前回起動分の記録を消さない。
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/infrastructure/cross_app_link_status.dart';
import 'package:book_review_app/core/infrastructure/cross_app_link_status_store.dart';

DateTime _fixedNow() => DateTime(2026, 11, 11, 9, 0);

void main() {
  group('CrossAppLinkStatusRecorder', () {
    late InMemoryCrossAppLinkStatusStore store;
    late CrossAppLinkStatusRecorder recorder;

    setUp(() {
      store = InMemoryCrossAppLinkStatusStore();
      recorder = CrossAppLinkStatusRecorder(store: store, now: _fixedNow);
    });

    test('初期状態は空', () async {
      final snapshot = await recorder.load();
      expect(snapshot.lastSent, isNull);
      expect(snapshot.lastReceived, isNull);
      expect(snapshot.sharedFolderReady, isFalse);
    });

    test('recordSent は最終送信を件数・ファイル名つきで残す', () async {
      await recorder.recordSent(count: 2, fileName: 'a.jsonl');

      final saved = await store.load();
      expect(saved.lastSent, isNotNull);
      expect(saved.lastSent!.ok, isTrue);
      expect(saved.lastSent!.count, 2);
      expect(saved.lastSent!.fileName, 'a.jsonl');
      expect(saved.lastSent!.at, _fixedNow());
      expect(saved.lastReceived, isNull);
      expect(store.saveCount, 1);
    });

    test('recordSendFailure は ok=false と理由を残す', () async {
      await recorder.recordSendFailure(
        StateError('disk full'),
        fileName: 'b.jsonl',
      );

      final saved = await store.load();
      expect(saved.lastSent!.ok, isFalse);
      expect(saved.lastSent!.count, 0);
      expect(saved.lastSent!.fileName, 'b.jsonl');
      expect(saved.lastSent!.error, contains('disk full'));
    });

    test('recordReceived は最終受信だけを更新する', () async {
      await recorder.recordSent(count: 1, fileName: 'a.jsonl');
      await recorder.recordReceived(count: 4, fileName: 'c.jsonl');

      final saved = await store.load();
      expect(saved.lastSent!.fileName, 'a.jsonl');
      expect(saved.lastReceived!.ok, isTrue);
      expect(saved.lastReceived!.count, 4);
      expect(saved.lastReceived!.fileName, 'c.jsonl');
    });

    test('recordFolderReady は共有フォルダ状態だけを変える', () async {
      await recorder.recordSent(count: 1);
      await recorder.recordFolderReady(true);

      final saved = await store.load();
      expect(saved.sharedFolderReady, isTrue);
      expect(saved.lastSent, isNotNull);
      expect(saved.lastReceived, isNull);
      expect(recorder.cached.sharedFolderReady, isTrue);
    });

    test('保存が throw しても呼び出し側へ漏れない', () async {
      store.throwOnSave = true;

      await expectLater(recorder.recordSent(count: 1), completes);
      await expectLater(recorder.recordReceived(count: 1), completes);
      await expectLater(recorder.recordFolderReady(true), completes);
      // 保存は失敗してもメモリ側の状態は進む（画面が嘘をつかない）。
      expect(recorder.cached.lastSent, isNotNull);
      expect(recorder.cached.sharedFolderReady, isTrue);
    });

    test('読込が throw しても空から始めて throw しない', () async {
      final broken = _ThrowingLoadStore();
      final r = CrossAppLinkStatusRecorder(store: broken, now: _fixedNow);

      final snapshot = await r.load();
      expect(snapshot.lastSent, isNull);
      await expectLater(r.recordSent(count: 1), completes);
      expect(r.cached.lastSent, isNotNull);
    });

    test('並行10件でも取りこぼさない（書込が直列化される）', () async {
      await Future.wait(<Future<void>>[
        for (var i = 0; i < 10; i++)
          recorder.recordSent(count: i + 1, fileName: 'f$i.jsonl'),
      ]);

      expect(store.saveCount, 10);
      final saved = await store.load();
      // 最後に書かれた記録は 10 件目。
      expect(saved.lastSent!.count, 10);
      expect(saved.lastSent!.fileName, 'f9.jsonl');
    });

    test('load 前の記録でも保存済みの前回値を消さない', () async {
      final previous = CrossAppLinkSnapshot(
        lastReceived: CrossAppTransferRecord(
          at: DateTime(2026, 11, 10, 8),
          ok: true,
          count: 7,
          fileName: 'prev.jsonl',
        ),
        sharedFolderReady: true,
      );
      final s = InMemoryCrossAppLinkStatusStore(previous);
      final r = CrossAppLinkStatusRecorder(store: s, now: _fixedNow);

      // load を明示的に呼ばずに記録する。
      await r.recordSent(count: 1, fileName: 'now.jsonl');

      final saved = await s.load();
      expect(saved.lastReceived, isNotNull);
      expect(saved.lastReceived!.count, 7);
      expect(saved.lastReceived!.fileName, 'prev.jsonl');
      expect(saved.sharedFolderReady, isTrue);
      expect(saved.lastSent!.fileName, 'now.jsonl');
    });

    test('reset で instance を差し替えられる（試練の差し込み口）', () {
      final r = CrossAppLinkStatusRecorder(store: store, now: _fixedNow);
      CrossAppLinkStatusRecorder.reset(r);
      expect(CrossAppLinkStatusRecorder.instance, same(r));

      CrossAppLinkStatusRecorder.reset();
      expect(CrossAppLinkStatusRecorder.instance, isNot(same(r)));
    });
  });
}

/// load が必ず失敗するストア（保存済みが壊れた端末の再現）。
class _ThrowingLoadStore implements ICrossAppLinkStatusStore {
  CrossAppLinkSnapshot saved = CrossAppLinkSnapshot.empty;

  @override
  Future<CrossAppLinkSnapshot> load() async => throw StateError('broken');

  @override
  Future<void> save(CrossAppLinkSnapshot snapshot) async {
    saved = snapshot;
  }
}
