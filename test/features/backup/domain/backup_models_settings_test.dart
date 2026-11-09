import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/backup/domain/backup_settings_spec.dart';

BackupBundle _bundle({BackupSettingsBundle? settings}) => BackupBundle(
      exportedAt: DateTime.utc(2026, 11, 9, 0, 0),
      books: const [],
      reviews: const [],
      notes: const [],
      settings: settings,
    );

void main() {
  group('BackupBundle.settings（任意項目）', () {
    test('settings 無しの toJson は従来と完全同一（キーが増えない）', () {
      final json = _bundle().toJson();

      expect(json.containsKey('settings'), isFalse);
      expect(
        json.keys.toList(),
        <String>['schemaVersion', 'exportedAt', 'books', 'reviews', 'notes'],
      );
    });

    test('settings 有りの toJson に settings が載る', () {
      final json = _bundle(
        settings: const BackupSettingsBundle(
          values: <String, Object?>{'book_review_theme_mode': 'dark'},
        ),
      ).toJson();

      expect(json['settings'], isA<Map<String, dynamic>>());
      final settings = json['settings'] as Map<String, dynamic>;
      expect(settings['schemaVersion'], kBackupSettingsSchemaVersion);
      expect(
        (settings['values'] as Map<String, dynamic>)['book_review_theme_mode'],
        'dark',
      );
    });

    test('settings 有りの往復で設定が戻る', () {
      final original = _bundle(
        settings: const BackupSettingsBundle(
          values: <String, Object?>{
            'book_review_theme_mode': 'dark',
            'book_review_text_scale': 1.25,
          },
        ),
      );

      final restored = BackupBundle.fromJson(original.toJson());

      expect(restored.settings, isNotNull);
      expect(restored.settings!.values, <String, Object?>{
        'book_review_theme_mode': 'dark',
        'book_review_text_scale': 1.25,
      });
    });

    test('settings 欠落の旧控えも従来どおり成功し、settings は null', () {
      final legacy = _bundle().toJson();

      final restored = BackupBundle.fromJson(legacy);

      expect(restored.settings, isNull);
      expect(restored.schemaVersion, kBackupSchemaVersion);
      expect(restored.exportedAt, DateTime.utc(2026, 11, 9, 0, 0));
    });

    test('settings が破損していても本体は成功し、settings は null', () {
      for (final broken in <Object?>[
        'broken',
        42,
        <Object>[1],
        <String, Object?>{}
      ]) {
        final json = _bundle().toJson();
        json['settings'] = broken;

        final restored = BackupBundle.fromJson(json);

        expect(restored.settings, isNull, reason: '$broken');
        expect(restored.books, isEmpty);
      }
    });

    test('BackupService の JSON 往復でも settings が保たれる', () {
      const service = BackupService();
      final json = service.exportJson(
        _bundle(
          settings: const BackupSettingsBundle(
            values: <String, Object?>{'book_reduce_motion': 'on'},
          ),
        ),
      );

      expect(json.contains('"settings"'), isTrue);
      expect(service.parse(json).settings!.values, <String, Object?>{
        'book_reduce_motion': 'on',
      });
    });

    test('settings 無しの JSON 文字列は従来と同一（バイト一致）', () {
      const service = BackupService();
      final withNull = service.exportJson(_bundle());

      expect(withNull.contains('settings'), isFalse);
      expect(service.parse(withNull).settings, isNull);
    });
  });
}
