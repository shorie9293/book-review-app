import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_presenter.dart';

void main() {
  const presenter = AutoBackupPresenter();

  group('formatDate', () {
    test('ローカル暦の yyyy-MM-dd HH:mm で0詰めする', () {
      expect(
        AutoBackupPresenter.formatDate(DateTime(2026, 1, 5, 7, 3)),
        '2026-01-05 07:03',
      );
      expect(
        AutoBackupPresenter.formatDate(DateTime(2026, 10, 29, 23, 59)),
        '2026-10-29 23:59',
      );
    });
  });

  group('formatSize', () {
    test('1024 未満は B', () {
      expect(AutoBackupPresenter.formatSize(0), '0 B');
      expect(AutoBackupPresenter.formatSize(512), '512 B');
      expect(AutoBackupPresenter.formatSize(1023), '1023 B');
    });

    test('1024 以上 1MB 未満は KB（小数1桁）', () {
      expect(AutoBackupPresenter.formatSize(1024), '1.0 KB');
      expect(AutoBackupPresenter.formatSize(12697), '12.4 KB');
      expect(AutoBackupPresenter.formatSize(1024 * 1024 - 1), '1024.0 KB');
    });

    test('1MB 以上は MB（小数1桁）', () {
      expect(AutoBackupPresenter.formatSize(1024 * 1024), '1.0 MB');
      expect(AutoBackupPresenter.formatSize(1258291), '1.2 MB');
    });
  });

  group('canRestore', () {
    test('トップが Map の JSON のみ true', () {
      expect(AutoBackupPresenter.canRestore('{"schemaVersion":1}'), isTrue);
      expect(AutoBackupPresenter.canRestore('{}'), isTrue);
    });

    test('null・空・壊れた JSON・非 Map は false（例外を投げない）', () {
      expect(AutoBackupPresenter.canRestore(null), isFalse);
      expect(AutoBackupPresenter.canRestore(''), isFalse);
      expect(AutoBackupPresenter.canRestore('{'), isFalse);
      expect(AutoBackupPresenter.canRestore('not json'), isFalse);
      expect(AutoBackupPresenter.canRestore('[]'), isFalse);
      expect(AutoBackupPresenter.canRestore('"text"'), isFalse);
      expect(AutoBackupPresenter.canRestore('123'), isFalse);
    });
  });

  group('sortNewestFirst', () {
    test('createdAt 降順、同時刻は fileName 降順', () {
      final entries = [
        AutoBackupEntry(
          fileName: 'auto_backup_20260101.json',
          createdAt: DateTime(2026, 1, 1, 8),
        ),
        AutoBackupEntry(
          fileName: 'auto_backup_20260103.json',
          createdAt: DateTime(2026, 1, 3, 8),
        ),
        AutoBackupEntry(
          fileName: 'auto_backup_20260102.json',
          createdAt: DateTime(2026, 1, 2, 8),
        ),
        AutoBackupEntry(
          fileName: 'auto_backup_20260103b.json',
          createdAt: DateTime(2026, 1, 3, 8),
        ),
      ];

      final sorted = AutoBackupPresenter.sortNewestFirst(entries);

      expect(sorted.map((e) => e.fileName), [
        'auto_backup_20260103b.json',
        'auto_backup_20260103.json',
        'auto_backup_20260102.json',
        'auto_backup_20260101.json',
      ]);
      // 入力は破壊しない。
      expect(entries.first.fileName, 'auto_backup_20260101.json');
    });
  });

  group('buildRows', () {
    test('自動ファイルのみ・新しい順・世代1始まり・UTF-8長・表示文言', () {
      final older = AutoBackupEntry(
        fileName: 'auto_backup_20261028.json',
        createdAt: DateTime(2026, 10, 28, 6, 5),
      );
      final newer = AutoBackupEntry(
        fileName: 'auto_backup_20261029.json',
        createdAt: DateTime(2026, 10, 29, 7, 12),
      );
      final manual = AutoBackupEntry(
        fileName: 'manual_backup.json',
        createdAt: DateTime(2026, 10, 30),
      );

      final rows = presenter.buildRows(
        entries: [older, manual, newer],
        contents: {
          older.fileName: '{"a":1}',
          newer.fileName: 'あ' * 4232, // UTF-8 で 12696 バイト
          manual.fileName: '{}',
        },
      );

      expect(rows, hasLength(2));
      expect(rows.first.entry.fileName, newer.fileName);
      expect(rows.first.generation, 1);
      expect(rows.first.byteSize, 12696);
      expect(rows.first.sizeLabel, '12.4 KB');
      expect(rows.first.dateLabel, '2026-10-29 07:12');
      expect(rows.first.restorable, isFalse); // トップが文字列
      expect(rows.first.displayLabel, '2026-10-29 07:12 / 12.4 KB / 第1世代');

      expect(rows.last.entry.fileName, older.fileName);
      expect(rows.last.generation, 2);
      expect(rows.last.byteSize, 7);
      expect(rows.last.sizeLabel, '7 B');
      expect(rows.last.restorable, isTrue);
      expect(rows.last.displayLabel, '2026-10-28 06:05 / 7 B / 第2世代');
    });

    test('内容が無い世代は 0 B・復元不可', () {
      final entry = AutoBackupEntry(
        fileName: 'auto_backup_20261029.json',
        createdAt: DateTime(2026, 10, 29, 7),
      );
      final rows = presenter.buildRows(
        entries: [entry],
        contents: const {},
      );
      expect(rows.single.byteSize, 0);
      expect(rows.single.sizeLabel, '0 B');
      expect(rows.single.restorable, isFalse);
    });
  });

  group('retentionLabel', () {
    test('既定は3世代', () {
      expect(presenter.retentionLabel(2), '保持 3世代中 2件');
      expect(presenter.retentionLabel(0), '保持 3世代中 0件');
    });

    test('keep を指定できる', () {
      expect(
        const AutoBackupPresenter(keep: 5).retentionLabel(4),
        '保持 5世代中 4件',
      );
    });

    test('既定 keep は AutoBackupPolicy.defaultKeep', () {
      expect(
        presenter.retentionLabel(1),
        '保持 ${AutoBackupPolicy.defaultKeep}世代中 1件',
      );
    });
  });
}
