import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/domain/cross_app_link_code.dart';

void main() {
  group('InMemoryCrossAppLinkRepository', () {
    test('未保存なら null', () async {
      final repo = InMemoryCrossAppLinkRepository();
      expect(await repo.loadUserId(), isNull);
    });

    test('初期値を保持する', () async {
      final repo = InMemoryCrossAppLinkRepository(userId: 'abc');
      expect(await repo.loadUserId(), 'abc');
    });

    test('ensureUserId は生成して保存する', () async {
      final repo = InMemoryCrossAppLinkRepository();
      final generated = await repo.ensureUserId();

      expect(generated.isNotEmpty, isTrue);
      expect(isValidLinkCode(linkCodeOf(generated)), isTrue);
      expect(await repo.loadUserId(), generated);
    });

    test('ensureUserId は2回呼んでも同一の userId を返す（冪等）', () async {
      final repo = InMemoryCrossAppLinkRepository();
      final first = await repo.ensureUserId();
      final second = await repo.ensureUserId();
      expect(second, first);
    });

    test('既存値があれば ensureUserId はそれを返す', () async {
      final repo = InMemoryCrossAppLinkRepository(userId: 'existing-id');
      expect(await repo.ensureUserId(), 'existing-id');
    });
  });

  group('NoopCrossAppLinkRepository', () {
    test('常に null と空文字', () async {
      const repo = NoopCrossAppLinkRepository();
      expect(await repo.loadUserId(), isNull);
      expect(await repo.ensureUserId(), '');
      expect(await repo.ensureUserId(), '');
    });
  });

  group('HiveCrossAppLinkRepository', () {
    late Directory tempDir;

    setUpAll(() {
      tempDir =
          Directory.systemTemp.createTempSync('book_review_cross_app_link');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      if (Hive.isBoxOpen(HiveCrossAppLinkRepository.boxName)) {
        await Hive.box<dynamic>(HiveCrossAppLinkRepository.boxName).close();
      }
      await Hive.deleteBoxFromDisk(HiveCrossAppLinkRepository.boxName);
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('未保存なら null', () async {
      const repo = HiveCrossAppLinkRepository();
      expect(await repo.loadUserId(), isNull);
    });

    test('ensureUserId が生成・永続化し、再読込でも同一', () async {
      const repo = HiveCrossAppLinkRepository();
      final first = await repo.ensureUserId();
      expect(first.isNotEmpty, isTrue);
      expect(isValidLinkCode(linkCodeOf(first)), isTrue);

      // 新しいインスタンスでも Hive から読める
      const reopened = HiveCrossAppLinkRepository();
      expect(await reopened.loadUserId(), first);
      expect(await reopened.ensureUserId(), first);
    });

    test('破損値（String以外）は null 扱い', () async {
      final box = await Hive.openBox<dynamic>(
        HiveCrossAppLinkRepository.boxName,
      );
      await box.put(HiveCrossAppLinkRepository.userIdKey, 12345);
      await box.put('other', 'x');

      const repo = HiveCrossAppLinkRepository();
      expect(await repo.loadUserId(), isNull);
    });

    test('空文字の保存値も null 扱い', () async {
      final box = await Hive.openBox<dynamic>(
        HiveCrossAppLinkRepository.boxName,
      );
      await box.put(HiveCrossAppLinkRepository.userIdKey, '   ');

      const repo = HiveCrossAppLinkRepository();
      expect(await repo.loadUserId(), isNull);
    });
  });
}
