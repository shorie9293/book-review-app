// 現世間の受け渡し状態（純粋モデル）の試練。
//
// 保存値は端末再起動や書込競合で壊れるのが日常なので、
// 「壊れていても throw せず空として読む」ことを固定する。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/infrastructure/cross_app_link_status.dart';

CrossAppTransferRecord _rec({
  DateTime? at,
  bool ok = true,
  int count = 1,
  String? fileName,
  String? error,
}) =>
    CrossAppTransferRecord(
      at: at ?? DateTime(2026, 11, 11, 9, 5),
      ok: ok,
      count: count,
      fileName: fileName,
      error: error,
    );

void main() {
  group('CrossAppTransferRecord.toJson / tryFromJson', () {
    test('往復しても値が変わらない', () {
      final original = _rec(
        count: 3,
        fileName: 'tsundoku_reward_events.jsonl',
        error: null,
      );
      final restored = CrossAppTransferRecord.tryFromJson(original.toJson())!;
      expect(restored.at, original.at);
      expect(restored.ok, isTrue);
      expect(restored.count, 3);
      expect(restored.fileName, 'tsundoku_reward_events.jsonl');
      expect(restored.error, isNull);
    });

    test('失敗記録は理由つきで往復する', () {
      final original = _rec(ok: false, count: 0, error: 'boom');
      final json = original.toJson();
      expect(json['ok'], isFalse);
      expect(json['count'], 0);
      final restored = CrossAppTransferRecord.tryFromJson(json)!;
      expect(restored.ok, isFalse);
      expect(restored.error, 'boom');
    });

    test('file / error が null なら JSON に載せない', () {
      final json = _rec().toJson();
      expect(json.containsKey('file'), isFalse);
      expect(json.containsKey('error'), isFalse);
    });

    test('Map でない値は null（throw しない）', () {
      expect(CrossAppTransferRecord.tryFromJson(null), isNull);
      expect(CrossAppTransferRecord.tryFromJson('txt'), isNull);
      expect(CrossAppTransferRecord.tryFromJson(<Object?>[]), isNull);
      expect(CrossAppTransferRecord.tryFromJson(42), isNull);
    });

    test('at が欠落・不正なら null', () {
      expect(CrossAppTransferRecord.tryFromJson(<String, Object?>{}), isNull);
      expect(
        CrossAppTransferRecord.tryFromJson(<String, Object?>{'at': 1}),
        isNull,
      );
      expect(
        CrossAppTransferRecord.tryFromJson(
            <String, Object?>{'at': 'not-a-date'}),
        isNull,
      );
    });

    test('ok が bool 以外なら false、count が num なら int へ寄せる', () {
      final r = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T00:05:00.000',
        'ok': 'yes',
        'count': 2.0,
      })!;
      expect(r.ok, isFalse);
      expect(r.count, 2);
    });

    test('count が欠落・非数値なら 0、file / error が空文字なら null', () {
      final r = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T00:05:00.000',
        'ok': true,
        'count': 'x',
        'file': '',
        'error': '',
      })!;
      expect(r.count, 0);
      expect(r.fileName, isNull);
      expect(r.error, isNull);
    });
  });

  group('CrossAppLinkSnapshot encode / decode', () {
    test('往復しても値が変わらない', () {
      final snapshot = CrossAppLinkSnapshot(
        lastSent: _rec(count: 2, fileName: 'a.jsonl'),
        lastReceived: _rec(ok: false, count: 0, error: 'io'),
        sharedFolderReady: true,
      );
      final restored = CrossAppLinkSnapshot.decode(snapshot.encode());
      expect(restored.sharedFolderReady, isTrue);
      expect(restored.lastSent!.count, 2);
      expect(restored.lastSent!.fileName, 'a.jsonl');
      expect(restored.lastReceived!.ok, isFalse);
      expect(restored.lastReceived!.error, 'io');
    });

    test('空スナップショットの往復', () {
      final restored = CrossAppLinkSnapshot.decode(
        CrossAppLinkSnapshot.empty.encode(),
      );
      expect(restored.lastSent, isNull);
      expect(restored.lastReceived, isNull);
      expect(restored.sharedFolderReady, isFalse);
    });

    test('null / 空文字 / 壊れた JSON は empty（throw しない）', () {
      for (final raw in <String?>[
        null,
        '',
        '   ',
        '{',
        '[1,2]',
        '"str"',
        '123',
      ]) {
        final decoded = CrossAppLinkSnapshot.decode(raw);
        expect(decoded.lastSent, isNull, reason: 'raw=$raw');
        expect(decoded.lastReceived, isNull, reason: 'raw=$raw');
        expect(decoded.sharedFolderReady, isFalse, reason: 'raw=$raw');
      }
    });

    test('型違いの入れ子でも throw せず空として読む', () {
      final raw = jsonEncode(<String, Object?>{
        'sharedFolderReady': 'yes',
        'lastSent': 'oops',
        'lastReceived': <String, Object?>{'at': 1},
      });
      final restored = CrossAppLinkSnapshot.decode(raw);
      expect(restored.sharedFolderReady, isFalse);
      expect(restored.lastSent, isNull);
      expect(restored.lastReceived, isNull);
    });

    test('copyWith は未指定の項目を保持する', () {
      final base = CrossAppLinkSnapshot(
        lastSent: _rec(count: 5),
        sharedFolderReady: true,
      );
      final next = base.copyWith(lastReceived: _rec(count: 1));
      expect(next.lastSent!.count, 5);
      expect(next.lastReceived!.count, 1);
      expect(next.sharedFolderReady, isTrue);
    });
  });

  group('CrossAppLinkStatusText', () {
    test('time は yyyy/MM/dd HH:mm、null は「未記録」', () {
      expect(
        CrossAppLinkStatusText.time(DateTime(2026, 11, 11, 9, 5)),
        '2026/11/11 09:05',
      );
      expect(CrossAppLinkStatusText.time(null), '未記録');
    });

    test('outcome は成功／失敗／未記録', () {
      expect(CrossAppLinkStatusText.outcome(_rec()), '成功');
      expect(CrossAppLinkStatusText.outcome(_rec(ok: false, count: 0)), '失敗');
      expect(CrossAppLinkStatusText.outcome(null), '未記録');
    });

    test('row は 成否・時刻・件数・ファイル名 を並べる', () {
      expect(
        CrossAppLinkStatusText.row(
          _rec(count: 3, fileName: 'tsundoku_reward_events.jsonl'),
        ),
        '成功・2026/11/11 09:05・3件・tsundoku_reward_events.jsonl',
      );
    });

    test('row はファイル名が無ければ省き、null は「未記録」', () {
      expect(
        CrossAppLinkStatusText.row(_rec(count: 0, ok: false)),
        '失敗・2026/11/11 09:05・0件',
      );
      expect(CrossAppLinkStatusText.row(null), '未記録');
    });

    test('folder は設定済み／未設定を出し分ける', () {
      expect(CrossAppLinkStatusText.folder(true), '設定済み');
      expect(CrossAppLinkStatusText.folder(false), '未設定（連携は停止中）');
    });

    test('detail は失敗理由のみ、長すぎれば切り詰める', () {
      expect(CrossAppLinkStatusText.detail(_rec()), '');
      expect(CrossAppLinkStatusText.detail(null), '');
      expect(CrossAppLinkStatusText.detail(_rec(ok: false, error: 'io')), 'io');
      final long = 'a' * 300;
      final cut = CrossAppLinkStatusText.detail(_rec(ok: false, error: long));
      expect(cut.endsWith('…'), isTrue);
      expect(cut.length, 161);
    });

    test('countLines は行数、空・null は 0', () {
      expect(CrossAppLinkStatusText.countLines(null), 0);
      expect(CrossAppLinkStatusText.countLines(''), 0);
      expect(CrossAppLinkStatusText.countLines('  \n '), 0);
      expect(CrossAppLinkStatusText.countLines('{"a":1}'), 1);
      expect(CrossAppLinkStatusText.countLines('{"a":1}\n{"b":2}\n'), 2);
      expect(CrossAppLinkStatusText.countLines('1\n2\n3'), 3);
    });
  });
}
