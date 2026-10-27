import 'dart:io';

import 'package:book_review_app/features/reminder/data/quiet_hours_repository.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_service.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/hive_quiet_hours_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('InMemoryQuietHoursRepository', () {
    test('既定値と観測カウンタ', () async {
      final repo = InMemoryQuietHoursRepository();
      expect(await repo.load(), QuietHoursSettings.defaults());
      expect(repo.loadCount, 1);

      final s = QuietHoursSettings(enabled: true, policy: QuietHoursPolicy.skip);
      await repo.save(s);
      expect(repo.saveCount, 1);
      expect(repo.current, s);
      expect(await repo.load(), s);
    });
  });

  group('NoopQuietHoursRepository', () {
    test('常に既定値・保存は捨てる', () async {
      final repo = NoopQuietHoursRepository();
      await repo.save(QuietHoursSettings(enabled: true));
      expect(await repo.load(), QuietHoursSettings.defaults());
    });
  });

  group('QuietHoursRepositoryGuard', () {
    test('defer 設定は翌朝へ繰り延べる', () async {
      final guard = QuietHoursRepositoryGuard(
        InMemoryQuietHoursRepository(QuietHoursSettings(enabled: true)),
      );
      expect(
        await guard.adjust(DateTime(2026, 10, 8, 23, 0)),
        DateTime(2026, 10, 9, 7, 0),
      );
    });

    test('skip 設定は null', () async {
      final guard = QuietHoursRepositoryGuard(
        InMemoryQuietHoursRepository(
          QuietHoursSettings(enabled: true, policy: QuietHoursPolicy.skip),
        ),
      );
      expect(await guard.adjust(DateTime(2026, 10, 8, 23, 0)), isNull);
    });

    test('無効設定はそのまま返す', () async {
      final guard = QuietHoursRepositoryGuard(InMemoryQuietHoursRepository());
      final scheduled = DateTime(2026, 10, 8, 23, 0);
      expect(await guard.adjust(scheduled), scheduled);
    });
  });

  group('HiveQuietHoursRepository', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('quiet_hours_hive');
      Hive.init(tmpDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('box 名は既存リマインダーと衝突しない', () {
      expect(HiveQuietHoursRepository.boxName, 'quiet_hours_box');
      expect(HiveQuietHoursRepository.boxName, isNot('reading_reminder_box'));
    });

    test('未保存なら既定値', () async {
      final repo = HiveQuietHoursRepository();
      expect(await repo.load(), QuietHoursSettings.defaults());
    });

    test('save → load 復元', () async {
      final repo = HiveQuietHoursRepository();
      final s = QuietHoursSettings(
        enabled: true,
        startHour: 21,
        startMinute: 30,
        endHour: 6,
        endMinute: 15,
        policy: QuietHoursPolicy.skip,
      );
      await repo.save(s);
      expect(await repo.load(), s);
    });

    test('破損レコードは既定値へフォールバック', () async {
      final box =
          await Hive.openBox<String>(HiveQuietHoursRepository.boxName);
      await box.put(HiveQuietHoursRepository.keyName, '{not json');
      final repo = HiveQuietHoursRepository();
      expect(await repo.load(), QuietHoursSettings.defaults());
    });

    test('openIfMissing=false は既に open 済みの box を読む', () async {
      final box =
          await Hive.openBox<String>(HiveQuietHoursRepository.boxName);
      await box.put(
        HiveQuietHoursRepository.keyName,
        '{"enabled":true,"startHour":22,"startMinute":0,'
            '"endHour":7,"endMinute":0,"policy":"skip"}',
      );
      final repo = HiveQuietHoursRepository(openIfMissing: false);
      final loaded = await repo.load();
      expect(loaded.enabled, isTrue);
      expect(loaded.policy, QuietHoursPolicy.skip);
    });
  });

  group('Hive 未初期化（通知経路の保険）', () {
    test('openIfMissing=false は例外を投げず既定値を返す', () async {
      final repo = HiveQuietHoursRepository(openIfMissing: false);
      final loaded = await repo.load();
      expect(loaded, QuietHoursSettings.defaults());
      // 既定（無効）なので通知は従来通り素通しになる。
      final scheduled = DateTime(2026, 10, 8, 23, 0);
      expect(
        QuietHoursService.resolveDelivery(loaded, scheduled),
        scheduled,
      );
    });
  });
}
