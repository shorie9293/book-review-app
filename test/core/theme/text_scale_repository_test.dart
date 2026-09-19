import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/theme/text_scale_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_text_scale_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('settings');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('TextScaleRepository (Hive)', () {
    test('loadScale returns null when unset', () async {
      final repo = TextScaleRepository();
      expect(await repo.loadScale(), isNull);
    });

    test('save + load round-trip', () async {
      final repo = TextScaleRepository();
      await repo.saveScale(1.25);
      expect(await repo.loadScale(), 1.25);

      await repo.saveScale(0.9);
      expect(await repo.loadScale(), 0.9);
    });

    test('loadScale returns null for invalid stored value', () async {
      final repo = TextScaleRepository();
      final box = await Hive.openBox<double>('settings');
      await box.put('book_review_text_scale', 3.3);
      expect(await repo.loadScale(), isNull);
    });

    test('saveScale throws ArgumentError for disallowed value', () async {
      final repo = TextScaleRepository();
      expect(
        () => repo.saveScale(1.5),
        throwsArgumentError,
      );
      expect(
        () => repo.saveScale(0.0),
        throwsArgumentError,
      );
    });
  });
}
