import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';

/// 呼び出し順を記録するストア。
class _RecordingStore implements AutoBackupStore {
  final Map<String, String> files = {};
  final List<String> ops = [];

  @override
  Future<List<AutoBackupEntry>> list() async {
    return [
      for (final name in files.keys)
        if (AutoBackupPolicy.isAutoBackupFile(name))
          AutoBackupEntry(fileName: name, createdAt: DateTime(2026, 1, 1)),
    ];
  }

  @override
  Future<void> write(String fileName, String json) async {
    ops.add('write:$fileName');
    files[fileName] = json;
  }

  @override
  Future<String?> read(String fileName) async {
    ops.add('read:$fileName');
    return files[fileName];
  }

  @override
  Future<void> delete(String fileName) async {
    ops.add('delete:$fileName');
    files.remove(fileName);
  }
}

void main() {
  final now = DateTime(2026, 10, 29, 7, 12);
  final target = 'auto_backup_20261001.json';

  AutoBackupRestorerImpl build(
    _RecordingStore store, {
    Future<String> Function()? buildCurrentJson,
    Future<void> Function(String json)? applyBackup,
  }) {
    return AutoBackupRestorerImpl(
      store: store,
      buildCurrentJson: buildCurrentJson ?? () async => '{"current":true}',
      applyBackup: applyBackup ?? (_) async {},
      now: () => now,
    );
  }

  test('復元前に現状を強制保存し、その後に適用する', () async {
    final store = _RecordingStore();
    store.files[target] = '{"schemaVersion":1}';
    final applied = <String>[];
    final restorer = build(store, applyBackup: (json) async => applied.add(json));

    final result = await restorer.restore(target);

    expect(result.ok, isTrue);
    expect(result.safetyFileName, 'auto_backup_20261029.json');
    expect(applied, ['{"schemaVersion":1}']);
    expect(store.ops, [
      'read:$target',
      'write:auto_backup_20261029.json',
    ]);
    expect(store.files['auto_backup_20261029.json'], '{"current":true}');
  });

  test('不正 JSON は復元せず、現状保存もしない', () async {
    final store = _RecordingStore();
    store.files[target] = 'not json';
    var applyCount = 0;
    final restorer = build(store, applyBackup: (_) async => applyCount++);

    final result = await restorer.restore(target);

    expect(result.ok, isFalse);
    expect(applyCount, 0);
    expect(store.files.containsKey('auto_backup_20261029.json'), isFalse);
    expect(result.message, isNotEmpty);
  });

  test('存在しない世代は ok:false', () async {
    final store = _RecordingStore();
    var applyCount = 0;
    final restorer = build(store, applyBackup: (_) async => applyCount++);

    final result = await restorer.restore(target);

    expect(result.ok, isFalse);
    expect(applyCount, 0);
  });

  test('現状保存が失敗したら適用しない（ok:false・例外は握る）', () async {
    final store = _RecordingStore();
    store.files[target] = '{"schemaVersion":1}';
    var applyCount = 0;
    final restorer = build(
      store,
      buildCurrentJson: () async => throw StateError('採取失敗'),
      applyBackup: (_) async => applyCount++,
    );

    final result = await restorer.restore(target);

    expect(result.ok, isFalse);
    expect(applyCount, 0);
  });

  test('適用が失敗しても ok:false（現状は保存済み）', () async {
    final store = _RecordingStore();
    store.files[target] = '{"schemaVersion":1}';
    final restorer = build(
      store,
      applyBackup: (_) async => throw const FormatException('不正'),
    );

    final result = await restorer.restore(target);

    expect(result.ok, isFalse);
    expect(store.files['auto_backup_20261029.json'], '{"current":true}');
  });
}
