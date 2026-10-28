import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_bootstrap.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';

void main() {
  group('scheduleAutoBackup', () {
    test('投げっぱなしで起動を止めず、裏で1件書き出す', () async {
      final now = DateTime(2026, 1, 5, 12);
      final store = InMemoryAutoBackupStore(now: () => now);

      // await せずに戻る（起動を待たせない）。
      expect(
        () => scheduleAutoBackup(
          buildJson: () async => '{"books":[]}',
          store: store,
        ),
        returnsNormally,
      );

      await pumpEventQueue();

      final listed = await store.list();
      expect(
        listed.map((e) => e.fileName),
        [AutoBackupPolicy.fileNameFor(DateTime.now())],
      );
    });

    test('JSON生成が失敗しても例外を外へ漏らさない', () async {
      final store = InMemoryAutoBackupStore(now: () => DateTime(2026, 1, 5, 12));

      expect(
        () => scheduleAutoBackup(
          buildJson: () async => throw StateError('壊れた'),
          store: store,
        ),
        returnsNormally,
      );
      await pumpEventQueue();
      expect(await store.list(), isEmpty);
    });
  });
}
