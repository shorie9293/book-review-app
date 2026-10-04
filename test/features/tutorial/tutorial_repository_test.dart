import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/features/tutorial/data/tutorial_repository.dart';

void main() {
  group('HiveTutorialRepository', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tutorial_hive_test');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk(HiveTutorialRepository.boxName);
      tempDir.deleteSync(recursive: true);
    });

    test('未保存状態では isCompleted が false', () async {
      final repo = HiveTutorialRepository();
      expect(await repo.isCompleted(), isFalse);
    });

    test('markCompleted 後は isCompleted が true', () async {
      final repo = HiveTutorialRepository();
      await repo.markCompleted();
      expect(await repo.isCompleted(), isTrue);
    });

    test('reset 後は isCompleted が false に戻る', () async {
      final repo = HiveTutorialRepository();
      await repo.markCompleted();
      await repo.reset();
      expect(await repo.isCompleted(), isFalse);
    });

    test('完了状態はボックスに永続化されていること', () async {
      await HiveTutorialRepository().markCompleted();
      final box = await Hive.openBox<bool>(HiveTutorialRepository.boxName);
      expect(box.get(HiveTutorialRepository.key), isTrue);
    });
  });

  group('InMemoryTutorialRepository', () {
    test('既定は未完了', () async {
      final repo = InMemoryTutorialRepository();
      expect(await repo.isCompleted(), isFalse);
    });

    test('completed: true で完了扱い', () async {
      final repo = InMemoryTutorialRepository(completed: true);
      expect(await repo.isCompleted(), isTrue);
    });

    test('markCompleted / reset が動作する', () async {
      final repo = InMemoryTutorialRepository();
      await repo.markCompleted();
      expect(await repo.isCompleted(), isTrue);
      await repo.reset();
      expect(await repo.isCompleted(), isFalse);
    });
  });

  group('NoopTutorialRepository', () {
    test('isCompleted は常に true（チュートリアル非表示）', () async {
      const repo = NoopTutorialRepository();
      expect(await repo.isCompleted(), isTrue);
    });

    test('markCompleted / reset は例外を投げない', () async {
      const repo = NoopTutorialRepository();
      await repo.markCompleted();
      await repo.reset();
      expect(await repo.isCompleted(), isTrue);
    });
  });
}
