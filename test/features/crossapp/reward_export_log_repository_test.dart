import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';

void main() {
  group('InMemoryRewardExportLogRepository', () {
    test('初期状態は空集合', () async {
      final repo = InMemoryRewardExportLogRepository();
      expect(await repo.loadSentKeys(), isEmpty);
    });

    test('markSent で追加され、再読込できる', () async {
      final repo = InMemoryRewardExportLogRepository();
      await repo.markSent('b1|2026-01-01T00:00:00.000Z');
      expect(await repo.loadSentKeys(), {'b1|2026-01-01T00:00:00.000Z'});
    });

    test('markSent は冪等（重複追加しない）', () async {
      final repo = InMemoryRewardExportLogRepository();
      await repo.markSent('k1');
      await repo.markSent('k1');
      await repo.markSent('k2');
      expect(await repo.loadSentKeys(), {'k1', 'k2'});
    });
  });

  group('HiveRewardExportLogRepository', () {
    late Directory tempDir;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('book_review_export_log');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      if (Hive.isBoxOpen(HiveRewardExportLogRepository.boxName)) {
        await Hive.box<dynamic>(HiveRewardExportLogRepository.boxName).close();
      }
      await Hive.deleteBoxFromDisk(HiveRewardExportLogRepository.boxName);
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('未保存なら空集合', () async {
      const repo = HiveRewardExportLogRepository();
      expect(await repo.loadSentKeys(), isEmpty);
    });

    test('markSent が永続化され、再読込でも同一', () async {
      const repo = HiveRewardExportLogRepository();
      await repo.markSent('b1|');
      await repo.markSent('b2|');

      const reopened = HiveRewardExportLogRepository();
      expect(await reopened.loadSentKeys(), {'b1|', 'b2|'});
    });

    test('markSent は冪等（重複追加しない）', () async {
      const repo = HiveRewardExportLogRepository();
      await repo.markSent('k1');
      await repo.markSent('k1');

      final box = Hive.box<dynamic>(HiveRewardExportLogRepository.boxName);
      final stored = box.get(HiveRewardExportLogRepository.sentKeysKey);
      expect(stored, isA<List<dynamic>>());
      expect((stored as List<dynamic>).length, 1);
    });

    test('破損値は空集合へ降格', () async {
      final box = await Hive.openBox<dynamic>(
        HiveRewardExportLogRepository.boxName,
      );
      await box.put(HiveRewardExportLogRepository.sentKeysKey, 42);

      const repo = HiveRewardExportLogRepository();
      expect(await repo.loadSentKeys(), isEmpty);
    });

    test('破損（非文字列要素）は読み飛ばす', () async {
      final box = await Hive.openBox<dynamic>(
        HiveRewardExportLogRepository.boxName,
      );
      await box.put(
        HiveRewardExportLogRepository.sentKeysKey,
        <dynamic>['ok|', 7, null],
      );

      const repo = HiveRewardExportLogRepository();
      expect(await repo.loadSentKeys(), {'ok|'});
    });
  });
}
