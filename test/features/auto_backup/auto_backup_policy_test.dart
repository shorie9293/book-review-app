import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';

AutoBackupEntry _entry(String name, DateTime at) =>
    AutoBackupEntry(fileName: name, createdAt: at);

void main() {
  group('AutoBackupPolicy 既定値', () {
    test('世代3・間隔24時間・接頭辞/接尾辞が共通仕様どおり', () {
      const policy = AutoBackupPolicy();
      expect(AutoBackupPolicy.defaultKeep, 3);
      expect(policy.keep, 3);
      expect(policy.interval, const Duration(hours: 24));
      expect(AutoBackupPolicy.filePrefix, 'auto_backup_');
      expect(AutoBackupPolicy.fileSuffix, '.json');
    });
  });

  group('AutoBackupEntry', () {
    test('同一値は等価・異なる値は非等価', () {
      final at = DateTime(2026, 1, 5, 9);
      expect(_entry('auto_backup_20260105.json', at),
          _entry('auto_backup_20260105.json', at));
      expect(
          _entry('auto_backup_20260105.json', at).hashCode,
          _entry('auto_backup_20260105.json', at).hashCode);
      expect(_entry('auto_backup_20260105.json', at),
          isNot(_entry('auto_backup_20260104.json', at)));
      expect(_entry('auto_backup_20260105.json', at),
          isNot(_entry('auto_backup_20260105.json', at.add(const Duration(seconds: 1)))));
    });
  });

  group('shouldRun', () {
    final now = DateTime(2026, 1, 5, 12);

    test('前回記録なし（null）は実行する', () {
      expect(const AutoBackupPolicy().shouldRun(lastAt: null, now: now), isTrue);
    });

    test('ちょうど24時間前は実行する', () {
      expect(
        const AutoBackupPolicy()
            .shouldRun(lastAt: now.subtract(const Duration(hours: 24)), now: now),
        isTrue,
      );
    });

    test('23時間59分前は実行しない', () {
      expect(
        const AutoBackupPolicy().shouldRun(
          lastAt: now.subtract(const Duration(hours: 23, minutes: 59)),
          now: now,
        ),
        isFalse,
      );
    });

    test('未来時刻（時計ずれ）は実行する', () {
      expect(
        const AutoBackupPolicy()
            .shouldRun(lastAt: now.add(const Duration(days: 1)), now: now),
        isTrue,
      );
    });
  });

  group('fileNameFor / isAutoBackupFile', () {
    test('ローカル暦の yyyyMMdd をゼロ埋めして組み立てる', () {
      expect(
        AutoBackupPolicy.fileNameFor(DateTime(2026, 1, 5, 23, 59)),
        'auto_backup_20260105.json',
      );
      expect(
        AutoBackupPolicy.fileNameFor(DateTime(2026, 12, 31)),
        'auto_backup_20261231.json',
      );
    });

    test('自動バックアップ名のみ真を返す', () {
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_20260105.json'), isTrue);
      expect(AutoBackupPolicy.isAutoBackupFile('manual_backup.json'), isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_.json'), isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_20260105.txt'), isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_2026010.json'), isFalse);
    });
  });

  group('latestCreatedAt', () {
    test('自動ファイルの最新 createdAt を返す', () {
      final policy = const AutoBackupPolicy();
      final latest = policy.latestCreatedAt([
        _entry('auto_backup_20260103.json', DateTime(2026, 1, 3)),
        _entry('auto_backup_20260105.json', DateTime(2026, 1, 5)),
        _entry('auto_backup_20260104.json', DateTime(2026, 1, 4)),
      ]);
      expect(latest, DateTime(2026, 1, 5));
    });

    test('自動ファイルがなければ null・手動ファイルは無視する', () {
      final policy = const AutoBackupPolicy();
      expect(policy.latestCreatedAt(const []), isNull);
      expect(
        policy.latestCreatedAt([
          _entry('manual_backup.json', DateTime(2026, 2, 1)),
        ]),
        isNull,
      );
    });
  });

  group('prune', () {
    test('世代数を超えた古い自動ファイルを削除対象として返す', () {
      final policy = const AutoBackupPolicy();
      final victims = policy.prune([
        _entry('auto_backup_20260101.json', DateTime(2026, 1, 1)),
        _entry('auto_backup_20260102.json', DateTime(2026, 1, 2)),
        _entry('auto_backup_20260103.json', DateTime(2026, 1, 3)),
        _entry('auto_backup_20260104.json', DateTime(2026, 1, 4)),
      ]);
      expect(victims.map((e) => e.fileName), ['auto_backup_20260101.json']);
    });

    test('keep 以下なら削除対象なし', () {
      final policy = const AutoBackupPolicy();
      expect(
        policy.prune([
          _entry('auto_backup_20260102.json', DateTime(2026, 1, 2)),
          _entry('auto_backup_20260103.json', DateTime(2026, 1, 3)),
          _entry('auto_backup_20260104.json', DateTime(2026, 1, 4)),
        ]),
        isEmpty,
      );
    });

    test('同一 createdAt は fileName 降順で新しい扱いにする', () {
      final policy = const AutoBackupPolicy(keep: 1);
      final at = DateTime(2026, 1, 5);
      final victims = policy.prune([
        _entry('auto_backup_20260101.json', at),
        _entry('auto_backup_20260102.json', at),
      ]);
      expect(victims.map((e) => e.fileName), ['auto_backup_20260101.json']);
    });

    test('手動ファイルは件数に数えず削除対象にもしない', () {
      final policy = const AutoBackupPolicy(keep: 1);
      final victims = policy.prune([
        _entry('manual_backup.json', DateTime(2026, 3, 1)),
        _entry('auto_backup_20260101.json', DateTime(2026, 1, 1)),
        _entry('auto_backup_20260102.json', DateTime(2026, 1, 2)),
      ]);
      expect(victims.map((e) => e.fileName), ['auto_backup_20260101.json']);
    });
  });
}
