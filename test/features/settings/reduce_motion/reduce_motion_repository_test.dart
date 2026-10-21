import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_reduce_motion_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('settings');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('ReduceMotionRepository (Hive)', () {
    test('未保存なら null', () async {
      const repo = ReduceMotionRepository();
      expect(await repo.load(), isNull);
    });

    test('save + load の往復が全設定で成立する', () async {
      const repo = ReduceMotionRepository();
      for (final setting in ReduceMotionSetting.values) {
        await repo.save(setting);
        expect(await repo.load(), setting);
      }
    });

    test('不正な保存値は null', () async {
      const repo = ReduceMotionRepository();
      final box = await Hive.openBox<String>('settings');
      await box.put('book_reduce_motion', 'invalid');
      expect(await repo.load(), isNull);
    });
  });

  group('InMemoryReduceMotionRepository', () {
    test('初期状態は未保存（null / saveCount 0）', () async {
      final repo = InMemoryReduceMotionRepository();
      expect(await repo.load(), isNull);
      expect(repo.saved, isNull);
      expect(repo.saveCount, 0);
    });

    test('save すると load で返り、saveCount が増える', () async {
      final repo = InMemoryReduceMotionRepository();
      await repo.save(ReduceMotionSetting.on);
      expect(await repo.load(), ReduceMotionSetting.on);
      expect(repo.saved, ReduceMotionSetting.on);
      expect(repo.saveCount, 1);
      await repo.save(ReduceMotionSetting.off);
      expect(repo.saved, ReduceMotionSetting.off);
      expect(repo.saveCount, 2);
    });

    test('ReduceMotionRepository として差し替え可能', () async {
      final ReduceMotionRepository repo = InMemoryReduceMotionRepository();
      expect(await repo.load(), isNull);
      await repo.save(ReduceMotionSetting.system);
      expect(await repo.load(), ReduceMotionSetting.system);
    });
  });
}
