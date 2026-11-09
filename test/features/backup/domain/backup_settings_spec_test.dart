import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/backup/domain/backup_settings_spec.dart';

void main() {
  group('kBackupSettingSpecs（許可リスト）', () {
    test('テーマ・文字サイズ・動きを減らす・チュートリアルが載っている', () {
      final keys = kBackupSettingSpecs.map((spec) => spec.key).toList();

      expect(
        keys,
        containsAll(<String>[
          'book_review_theme_mode',
          'book_review_text_scale',
          'book_reduce_motion',
          'book_review_tutorial_completed',
        ]),
      );
      expect(
        backupSettingSpecFor('book_review_theme_mode')!.category,
        BackupSettingCategory.settings,
      );
      expect(
        backupSettingSpecFor('book_review_text_scale')!.category,
        BackupSettingCategory.settings,
      );
      expect(
        backupSettingSpecFor('book_reduce_motion')!.category,
        BackupSettingCategory.settings,
      );
      expect(
        backupSettingSpecFor('book_review_tutorial_completed')!.category,
        BackupSettingCategory.tutorial,
      );
    });

    test('キーは重複しない', () {
      final keys = kBackupSettingSpecs.map((spec) => spec.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('label は空でない', () {
      for (final spec in kBackupSettingSpecs) {
        expect(spec.label, isNotEmpty, reason: spec.key);
      }
    });

    test('app_lock 系は isSecret として列挙される（控えに載せない）', () {
      final secrets =
          kBackupSettingSpecs.where((spec) => spec.isSecret).map((s) => s.key);

      expect(secrets, contains('app_lock.enabled'));
      expect(secrets, contains('app_lock.passcode_hash'));
      // 許可リストの先頭4件（テーマ・文字サイズ・動き・チュートリアル）は秘密でない
      expect(backupSettingSpecFor('book_review_theme_mode')!.isSecret, isFalse);
    });

    test('未知キーは null', () {
      expect(backupSettingSpecFor('unknown_key'), isNull);
    });
  });

  group('selectForBackup', () {
    test('許可リストのキーだけを通す（未知キーは落とす）', () {
      final selected = selectForBackup(<String, Object?>{
        'book_review_theme_mode': 'dark',
        'book_review_text_scale': 1.25,
        'book_reduce_motion': 'on',
        'book_review_tutorial_completed': true,
        'library_search_history_v1': <String>['検索語'],
        'unknown_key': 1,
      });

      expect(selected, <String, Object?>{
        'book_review_theme_mode': 'dark',
        'book_review_text_scale': 1.25,
        'book_reduce_motion': 'on',
        'book_review_tutorial_completed': true,
      });
    });

    test('秘密（app_lock 系）は許可リストに在っても落とす', () {
      final selected = selectForBackup(<String, Object?>{
        'app_lock.passcode_hash': 'v2:1200:deadbeef:cafe',
        'app_lock.enabled': true,
        'book_review_theme_mode': 'light',
      });

      expect(selected, <String, Object?>{'book_review_theme_mode': 'light'});
    });

    test('null 値と非スカラ値は落とす', () {
      final selected = selectForBackup(<String, Object?>{
        'book_review_theme_mode': null,
        'book_review_text_scale': <String, Object?>{'x': 1},
        'book_review_tutorial_completed': <String>['true'],
      });

      expect(selected, isEmpty);
    });

    test('生値が空なら空を返す', () {
      expect(selectForBackup(const <String, Object?>{}), isEmpty);
    });
  });

  group('BackupSettingsBundle', () {
    test('toJson / tryFromJson の往復で値が保存される', () {
      const bundle = BackupSettingsBundle(
        values: <String, Object?>{
          'book_review_theme_mode': 'dark',
          'book_review_text_scale': 0.9,
          'book_review_tutorial_completed': true,
        },
      );

      final restored = BackupSettingsBundle.tryFromJson(bundle.toJson());

      expect(restored, isNotNull);
      expect(restored!.schemaVersion, kBackupSettingsSchemaVersion);
      expect(restored.values, bundle.values);
    });

    test('非Map は throw せず null', () {
      expect(BackupSettingsBundle.tryFromJson(null), isNull);
      expect(BackupSettingsBundle.tryFromJson('broken'), isNull);
      expect(BackupSettingsBundle.tryFromJson(<Object>[1, 2]), isNull);
      expect(BackupSettingsBundle.tryFromJson(42), isNull);
    });

    test('破損（values 欠落・型不一致・版数不正）は null', () {
      expect(
        BackupSettingsBundle.tryFromJson(<String, Object?>{'schemaVersion': 1}),
        isNull,
      );
      expect(
        BackupSettingsBundle.tryFromJson(
          <String, Object?>{'schemaVersion': 1, 'values': 'broken'},
        ),
        isNull,
      );
      expect(
        BackupSettingsBundle.tryFromJson(
          <String, Object?>{'values': <String, Object?>{}},
        ),
        isNull,
      );
      expect(
        BackupSettingsBundle.tryFromJson(
          <String, Object?>{'schemaVersion': 0, 'values': <String, Object?>{}},
        ),
        isNull,
      );
    });

    test('値の非スカラ・null は捨てて残りを返す', () {
      final restored = BackupSettingsBundle.tryFromJson(<String, Object?>{
        'schemaVersion': 1,
        'values': <String, Object?>{
          'book_review_theme_mode': 'dark',
          'book_review_text_scale': null,
          'book_reduce_motion': <String>['on'],
        },
      });

      expect(restored, isNotNull);
      expect(restored!.values,
          <String, Object?>{'book_review_theme_mode': 'dark'});
    });
  });
}
