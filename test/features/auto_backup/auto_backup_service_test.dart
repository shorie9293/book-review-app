import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_service.dart';

/// 追加書き込みのみを許す検証用ストア（世代ローテーションの土台を用意する）。
InMemoryAutoBackupStore _storeWith(
  Map<String, DateTime> seed, {
  DateTime Function()? now,
}) {
  final store = InMemoryAutoBackupStore(now: now);
  seed.forEach((name, at) {
    store.seed(fileName: name, createdAt: at, contents: '{"seeded":true}');
  });
  return store;
}

void main() {
  final now = DateTime(2026, 1, 5, 12);

  group('InMemoryAutoBackupStore', () {
    test('書き込み・読み出し・一覧・削除ができる', () async {
      final store = InMemoryAutoBackupStore(now: () => now);
      await store.write('auto_backup_20260105.json', '{"a":1}');
      final listed = await store.list();
      expect(listed, hasLength(1));
      expect(listed.single.fileName, 'auto_backup_20260105.json');
      expect(listed.single.createdAt, now);
      expect(await store.read('auto_backup_20260105.json'), '{"a":1}');
      await store.delete('auto_backup_20260105.json');
      expect(await store.list(), isEmpty);
      expect(await store.read('auto_backup_20260105.json'), isNull);
    });
  });

  group('FileAutoBackupStore', () {
    late Directory dir;

    setUp(() async {
      dir = Directory('${Directory.current.path}/.dart_tool/auto_backup_test')
        ..createSync(recursive: true);
      for (final entity in dir.listSync()) {
        entity.deleteSync(recursive: true);
      }
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('auto_backups 配下へ書き出し、一覧は自動ファイルのみ返す', () async {
      final store = FileAutoBackupStore(directoryResolver: () async => dir);
      await store.write('auto_backup_20260105.json', '{"a":1}');
      File('${dir.path}/manual_backup.json').writeAsStringSync('{}');

      final listed = await store.list();
      expect(listed.map((e) => e.fileName), ['auto_backup_20260105.json']);
      expect(listed.single.createdAt.isAfter(DateTime(2000)), isTrue);
      expect(await store.read('auto_backup_20260105.json'), '{"a":1}');
    });

    test('削除すると一覧から消える', () async {
      final store = FileAutoBackupStore(directoryResolver: () async => dir);
      await store.write('auto_backup_20260105.json', '{"a":1}');
      await store.delete('auto_backup_20260105.json');
      expect(await store.list(), isEmpty);
      expect(File('${dir.path}/auto_backup_20260105.json').existsSync(), isFalse);
    });
  });

  group('AutoBackupService.run', () {
    test('前回記録がなければ当日分を書き出す', () async {
      final store = InMemoryAutoBackupStore(now: () => now);
      final service = AutoBackupService(store: store, now: () => now);

      final result = await service.run(() async => '{"books":[]}');

      expect(result.ran, isTrue);
      expect(result.fileName, 'auto_backup_20260105.json');
      expect(result.pruned, 0);
      expect(result.error, isNull);
      expect(await store.read('auto_backup_20260105.json'), '{"books":[]}');
    });

    test('24時間未満ならスキップし、JSON生成も呼ばない', () async {
      var builds = 0;
      final store = _storeWith({
        'auto_backup_20260104.json': now.subtract(const Duration(hours: 23)),
      });
      final service = AutoBackupService(store: store, now: () => now);

      final result = await service.run(() async {
        builds++;
        return '{"books":[]}';
      });

      expect(result.ran, isFalse);
      expect(result.error, isNull);
      expect(builds, 0);
      expect(await store.list(), hasLength(1));
    });

    test('同日の再実行は冪等（2回目はスキップ）', () async {
      final store = InMemoryAutoBackupStore(now: () => now);
      final service = AutoBackupService(store: store, now: () => now);

      final first = await service.run(() async => '{"books":[]}');
      final second = await service.run(() async => '{"books":[1]}');

      expect(first.ran, isTrue);
      expect(second.ran, isFalse);
      expect(await store.list(), hasLength(1));
      expect(await store.read('auto_backup_20260105.json'), '{"books":[]}');
    });

    test('世代3を超えた古い自動ファイルを削除し、手動ファイルは残す', () async {
      final store = _storeWith({
        'auto_backup_20260101.json': DateTime(2026, 1, 1),
        'auto_backup_20260102.json': DateTime(2026, 1, 2),
        'auto_backup_20260103.json': DateTime(2026, 1, 3),
        'manual_backup.json': DateTime(2026, 1, 1),
      });
      final service = AutoBackupService(store: store, now: () => now);

      final result = await service.run(() async => '{"books":[]}');

      expect(result.ran, isTrue);
      expect(result.pruned, 1);
      expect(
        (await store.list()).map((e) => e.fileName).toSet(),
        {
          'auto_backup_20260102.json',
          'auto_backup_20260103.json',
          'auto_backup_20260105.json',
        },
      );
      expect(await store.read('auto_backup_20260101.json'), isNull);
      // 手動ファイルは一覧に出さず、削除もしない。
      expect(await store.read('manual_backup.json'), isNotNull);
    });

    test('JSON生成が投げても例外を外へ出さず error に収める', () async {
      final store = InMemoryAutoBackupStore(now: () => now);
      final service = AutoBackupService(store: store, now: () => now);

      final result = await service.run(() async => throw StateError('壊れた'));

      expect(result.ran, isFalse);
      expect(result.error, isA<StateError>());
      expect(await store.list(), isEmpty);
    });

    test('書き込み失敗（ストア例外）も握って error にする', () async {
      final service = AutoBackupService(
        store: _ThrowingStore(),
        now: () => now,
      );

      final result = await service.run(() async => '{}');

      expect(result.ran, isFalse);
      expect(result.error, isA<FileSystemException>());
    });
  });
}

/// 書き込みで必ず失敗するストア（起動を止めないことの検証用）。
class _ThrowingStore implements AutoBackupStore {
  @override
  Future<List<AutoBackupEntry>> list() async => const [];

  @override
  Future<void> write(String fileName, String json) async {
    throw const FileSystemException('書き込み不能');
  }

  @override
  Future<String?> read(String fileName) async => null;

  @override
  Future<void> delete(String fileName) async {}
}
