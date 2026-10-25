import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/features/import/data/import_history_repository.dart';
import 'package:book_review_app/features/import/domain/import_history_entry.dart';

ImportHistoryEntry entry({
  required String id,
  DateTime? importedAt,
  String mode = 'csv',
  int addedCount = 1,
  List<String> sampleIsbns = const ['9784774189079'],
}) {
  return ImportHistoryEntry(
    id: id,
    importedAt: importedAt ?? DateTime(2026, 5, 1, 10, 30),
    mode: mode,
    addedCount: addedCount,
    skippedCount: 0,
    notFoundCount: 0,
    failedCount: 0,
    sampleIsbns: sampleIsbns,
  );
}

void main() {
  group('InMemoryImportHistoryRepository', () {
    test('初期値を渡せる', () async {
      final repo = InMemoryImportHistoryRepository([entry(id: 'a')]);
      final loaded = await repo.load();
      expect(loaded.map((e) => e.id), ['a']);
    });

    test('save/loadが往復する', () async {
      final repo = InMemoryImportHistoryRepository();
      expect(await repo.load(), isEmpty);

      await repo.save([entry(id: 'a'), entry(id: 'b', addedCount: 5)]);
      final loaded = await repo.load();

      expect(loaded.length, 2);
      expect(loaded.first, entry(id: 'a'));
      expect(loaded[1].addedCount, 5);
    });

    test('loadは内部リストの参照を漏らさない（防御的コピー）', () async {
      final repo = InMemoryImportHistoryRepository([entry(id: 'a')]);
      final loaded = await repo.load();
      loaded.add(entry(id: 'injected'));

      expect((await repo.load()).length, 1);
    });
  });

  group('HiveImportHistoryRepository', () {
    late Directory tempDir;
    var boxSeq = 0;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('import_history_test_');
      Hive.init(tempDir.path);
    });

    tearDownAll(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    /// 各試練で箱名を分け、箱同士の汚染を避ける
    Future<HiveImportHistoryRepository> freshRepo() async {
      final name = 'import_history_box_test_${boxSeq++}';
      final repo = HiveImportHistoryRepository();
      await repo.init(boxNameOverride: name);
      return repo;
    }

    Future<void> closeAndDelete(String name) async {
      await Hive.deleteBoxFromDisk(name);
    }

    test('save/loadが実ストレージで往復する', () async {
      final repo = await freshRepo();
      final name = repo.openedBoxName;

      await repo.save([
        entry(id: 'a'),
        entry(
            id: 'b',
            mode: 'isbn',
            addedCount: 7,
            sampleIsbns: const ['9784123456784']),
      ]);
      final loaded = await repo.load();

      expect(loaded.length, 2);
      expect(loaded[0], entry(id: 'a'));
      expect(loaded[1].mode, 'isbn');
      expect(loaded[1].addedCount, 7);
      expect(loaded[1].sampleIsbns, ['9784123456784']);

      await closeAndDelete(name);
    });

    test('saveは全置換（前回の残骸を残さない）', () async {
      final repo = await freshRepo();
      final name = repo.openedBoxName;

      await repo.save([entry(id: 'a'), entry(id: 'b')]);
      await repo.save([entry(id: 'c')]);

      expect((await repo.load()).map((e) => e.id), ['c']);

      await closeAndDelete(name);
    });

    test('空リストを保存すると空で読み戻る', () async {
      final repo = await freshRepo();
      final name = repo.openedBoxName;

      await repo.save([entry(id: 'a')]);
      await repo.save(const []);

      expect(await repo.load(), isEmpty);

      await closeAndDelete(name);
    });

    test('破損JSON要素は読み飛ばし、健全要素のみ返す', () async {
      final repo = await freshRepo();
      final box = Hive.box<String>(repo.openedBoxName);

      // 健全2件 + 壊れたJSON + 型不正JSON を混在させる
      await box.put(
        '${HiveImportHistoryRepository.storageKey}.0',
        jsonEncode(entry(id: 'ok1').toJson()),
      );
      await box.put('${HiveImportHistoryRepository.storageKey}.1', '{not json');
      await box.put(
        '${HiveImportHistoryRepository.storageKey}.2',
        jsonEncode({'id': '', 'importedAt': '2026-05-01T10:30:00.000'}),
      );
      await box.put(
        '${HiveImportHistoryRepository.storageKey}.3',
        jsonEncode(entry(id: 'ok2').toJson()),
      );

      final loaded = await repo.load();

      expect(loaded.map((e) => e.id), ['ok1', 'ok2']);

      await closeAndDelete(repo.openedBoxName);
    });

    test('init前のloadは例外を投げず空を返す', () async {
      final repo = HiveImportHistoryRepository();
      // init していない（箱は未オープン）
      expect(await repo.load(), isEmpty);
      // save も例外を投げない（best-effort）
      await repo.save([entry(id: 'a')]);
    });

    test('init失敗時もloadは空を返す（best-effort）', () async {
      final repo = HiveImportHistoryRepository();
      await repo.init(boxNameOverride: 'bad name with spaces/and slashes');
      expect(await repo.load(), isEmpty);
    });
  });
}
