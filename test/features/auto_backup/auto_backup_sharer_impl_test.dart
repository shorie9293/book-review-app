import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/auto_backup/data/auto_backup_sharer_impl.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory('${Directory.current.path}/.dart_tool/auto_backup_share_test')
      ..createSync(recursive: true);
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('一時領域へ書き出してから共有する', () async {
    String? sentText;
    String? sentPath;
    String? sentMime;
    String? sentName;
    final sharer = SharePlusAutoBackupSharer(
      directoryResolver: () async => dir,
      send: (file, text) async {
        sentPath = file.path;
        sentMime = file.mimeType;
        sentName = file.name;
        sentText = text;
      },
    );

    await sharer.share('auto_backup_20261029.json', '{"a":1}');

    expect(sentPath, '${dir.path}/auto_backup_20261029.json');
    expect(sentMime, 'application/json');
    expect(sentName, 'auto_backup_20261029.json');
    expect(sentText, contains('auto_backup_20261029.json'));
    expect(
      File('${dir.path}/auto_backup_20261029.json').readAsStringSync(),
      '{"a":1}',
    );
  });
}
