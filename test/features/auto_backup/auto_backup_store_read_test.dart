import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory('${Directory.current.path}/.dart_tool/auto_backup_read_test')
      ..createSync(recursive: true);
    for (final entity in dir.listSync()) {
      entity.deleteSync(recursive: true);
    }
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('FileAutoBackupStore.read は書き出した内容をそのまま返す', () async {
    final store = FileAutoBackupStore(directoryResolver: () async => dir);
    const json = '{"schemaVersion":1,"books":[],"note":"日本語"}';

    await store.write('auto_backup_20261029.json', json);

    expect(await store.read('auto_backup_20261029.json'), json);
  });

  test('FileAutoBackupStore.read は未存在なら null', () async {
    final store = FileAutoBackupStore(directoryResolver: () async => dir);

    expect(await store.read('auto_backup_20990101.json'), isNull);
  });

  test('InMemoryAutoBackupStore.read は書き込み内容・未存在 null', () async {
    final store = InMemoryAutoBackupStore(now: () => DateTime(2026, 10, 29));

    await store.write('auto_backup_20261029.json', '{"a":1}');

    expect(await store.read('auto_backup_20261029.json'), '{"a":1}');
    expect(await store.read('auto_backup_20261030.json'), isNull);
  });
}
