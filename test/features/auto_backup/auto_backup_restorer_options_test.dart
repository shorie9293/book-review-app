import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_restorer.dart';

/// 読み書きだけを記録するストア。
class _MemoryStore implements AutoBackupStore {
  final Map<String, String> files = {};

  @override
  Future<List<AutoBackupEntry>> list() async => [
        for (final name in files.keys)
          if (AutoBackupPolicy.isAutoBackupFile(name))
            AutoBackupEntry(fileName: name, createdAt: DateTime(2026, 1, 1)),
      ];

  @override
  Future<void> write(String fileName, String json) async =>
      files[fileName] = json;

  @override
  Future<String?> read(String fileName) async => files[fileName];

  @override
  Future<void> delete(String fileName) async => files.remove(fileName);
}

void main() {
  final target = 'auto_backup_20261001.json';
  const json = '{"schemaVersion":1,"settings":{"schemaVersion":1,"values":{}}}';

  _MemoryStore storeWithTarget() => _MemoryStore()..files[target] = json;

  test('AutoBackupRestorerWithOptions は AutoBackupRestorer の一種である', () {
    final restorer = AutoBackupRestorerImpl(
      store: storeWithTarget(),
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async {},
    );

    expect(restorer, isA<AutoBackupRestorer>());
    expect(restorer, isA<AutoBackupRestorerWithOptions>());
  });

  test('restoreWithOptions は includeSettings を適用経路へ渡す', () async {
    final applied = <bool>[];
    final restorer = AutoBackupRestorerImpl(
      store: storeWithTarget(),
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async {},
      applyBackupWithOptions: (json, {bool includeSettings = true}) async =>
          applied.add(includeSettings),
    );

    final result = await restorer.restoreWithOptions(
      target,
      includeSettings: false,
    );

    expect(result.ok, isTrue);
    expect(applied, <bool>[false]);
  });

  test('restoreWithOptions の既定は設定も戻す（true）', () async {
    final applied = <bool>[];
    final restorer = AutoBackupRestorerImpl(
      store: storeWithTarget(),
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async {},
      applyBackupWithOptions: (json, {bool includeSettings = true}) async =>
          applied.add(includeSettings),
    );

    await restorer.restoreWithOptions(target);

    expect(applied, <bool>[true]);
  });

  test('従来の restore は設定も戻す経路（true）で1回だけ適用する', () async {
    final applied = <bool>[];
    final restorer = AutoBackupRestorerImpl(
      store: storeWithTarget(),
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async {},
      applyBackupWithOptions: (json, {bool includeSettings = true}) async =>
          applied.add(includeSettings),
    );

    final result = await restorer.restore(target);

    expect(result.ok, isTrue);
    expect(applied, <bool>[true]);
  });

  test('設定適用の可否を渡せない旧経路だけでも従来どおり動く', () async {
    var calls = 0;
    final restorer = AutoBackupRestorerImpl(
      store: storeWithTarget(),
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async => calls++,
    );

    final result = await restorer.restoreWithOptions(
      target,
      includeSettings: false,
    );

    expect(result.ok, isTrue);
    expect(calls, 1);
  });

  test('設定適用後（includeSettings: true）に onSettingsRestored を呼ぶ', () async {
    var hooks = 0;
    final restorer = AutoBackupRestorerImpl(
      store: storeWithTarget(),
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async {},
      onSettingsRestored: () async => hooks++,
    );

    final result = await restorer.restore(target);
    await Future<void>.delayed(Duration.zero);

    expect(result.ok, isTrue);
    expect(hooks, 1);
  });

  test('includeSettings: false なら onSettingsRestored を呼ばない', () async {
    var hooks = 0;
    final restorer = AutoBackupRestorerImpl(
      store: storeWithTarget(),
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async {},
      onSettingsRestored: () async => hooks++,
    );

    await restorer.restoreWithOptions(target, includeSettings: false);
    await Future<void>.delayed(Duration.zero);

    expect(hooks, 0);
  });

  test('onSettingsRestored が投げても復元結果は ok:true', () async {
    final restorer = AutoBackupRestorerImpl(
      store: storeWithTarget(),
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async {},
      onSettingsRestored: () async => throw StateError('通知の再予約に失敗'),
    );

    final result = await restorer.restore(target);
    await Future<void>.delayed(Duration.zero);

    expect(result.ok, isTrue);
    expect(result.message, isNotEmpty);
  });
}
