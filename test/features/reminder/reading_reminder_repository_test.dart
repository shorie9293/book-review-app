import 'dart:io';

import 'package:book_review_app/features/reminder/data/reading_reminder_repository.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('InMemoryReadingReminderRepository', () {
    test('load は既定値を返す', () async {
      final repo = InMemoryReadingReminderRepository();
      final s = await repo.load();
      expect(s, ReadingReminderSettings.defaults());
    });

    test('初期値を注入できる', () async {
      final initial = ReadingReminderSettings(hour: 21, weekdays: const [1]);
      final repo = InMemoryReadingReminderRepository(initial);
      expect((await repo.load()).hour, 21);
    });

    test('save → load 往復', () async {
      final repo = InMemoryReadingReminderRepository();
      final s = ReadingReminderSettings(
        enabled: true,
        hour: 8,
        minute: 45,
        weekdays: const [2, 4],
        updatedAt: DateTime(2026, 10, 8, 9),
      );
      await repo.save(s);
      expect(await repo.load(), s);
    });
  });

  group('HiveReadingReminderRepository', () {
    late Directory tmpDir;

    setUpAll(() async {
      Hive.init(Directory.systemTemp.createTempSync().path);
    });

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync();
      Hive.init(tmpDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('未保存なら load は既定値', () async {
      final repo = HiveReadingReminderRepository();
      final s = await repo.load();
      expect(s, ReadingReminderSettings.defaults());
    });

    test('save → load 復元', () async {
      final repo = HiveReadingReminderRepository();
      final s = ReadingReminderSettings(
        enabled: true,
        hour: 7,
        minute: 30,
        weekdays: const [1, 3, 5],
        updatedAt: DateTime(2026, 10, 8, 10),
      );
      await repo.save(s);
      final loaded = await repo.load();
      expect(loaded, s);
      expect(loaded.weekdays, [1, 3, 5]);
    });

    test('破損レコードは既定値へフォールバック', () async {
      final repo = HiveReadingReminderRepository();
      final box = await Hive.openBox<String>(HiveReadingReminderRepository.boxName);
      await box.put(HiveReadingReminderRepository.keyName, '{not json');
      final loaded = await repo.load();
      expect(loaded, ReadingReminderSettings.defaults());
    });
  });
}
