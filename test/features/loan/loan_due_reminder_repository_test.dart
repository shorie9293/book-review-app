import 'dart:io';

import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('InMemoryLoanDueReminderRepository', () {
    test('load は既定値を返す', () async {
      final repo = InMemoryLoanDueReminderRepository();
      final s = await repo.load();
      expect(s, LoanDueReminderSettings.defaults());
    });

    test('初期値を注入できる', () async {
      final initial = LoanDueReminderSettings(hour: 21);
      final repo = InMemoryLoanDueReminderRepository(initial);
      expect((await repo.load()).hour, 21);
    });

    test('save → load 往復', () async {
      final repo = InMemoryLoanDueReminderRepository();
      final s = LoanDueReminderSettings(
        enabled: true,
        hour: 8,
        minute: 45,
        updatedAt: DateTime(2026, 10, 21, 9),
      );
      await repo.save(s);
      expect(await repo.load(), s);
    });
  });

  group('HiveLoanDueReminderRepository', () {
    late Directory tmpDir;

    setUpAll(() async {
      Hive.init(Directory.systemTemp.createTempSync().path);
    });

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync();
      Hive.init(tmpDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('boxName / keyName は固定値', () {
      expect(HiveLoanDueReminderRepository.boxName, 'loan_reminder_box');
      expect(HiveLoanDueReminderRepository.keyName, 'loanDueReminder');
    });

    test('未保存なら load は既定値', () async {
      final repo = HiveLoanDueReminderRepository();
      final s = await repo.load();
      expect(s, LoanDueReminderSettings.defaults());
    });

    test('save → load 復元', () async {
      final repo = HiveLoanDueReminderRepository();
      final s = LoanDueReminderSettings(
        enabled: true,
        hour: 7,
        minute: 30,
        updatedAt: DateTime(2026, 10, 21, 10),
      );
      await repo.save(s);
      final loaded = await repo.load();
      expect(loaded, s);
      expect(loaded.enabled, isTrue);
      expect(loaded.hour, 7);
      expect(loaded.minute, 30);
    });

    test('破損レコードは既定値へフォールバック', () async {
      final repo = HiveLoanDueReminderRepository();
      final box =
          await Hive.openBox<String>(HiveLoanDueReminderRepository.boxName);
      await box.put(HiveLoanDueReminderRepository.keyName, '{not json');
      final loaded = await repo.load();
      expect(loaded, LoanDueReminderSettings.defaults());
    });

    test('型不一致（JSON 配列）は既定値へフォールバック', () async {
      final repo = HiveLoanDueReminderRepository();
      final box =
          await Hive.openBox<String>(HiveLoanDueReminderRepository.boxName);
      await box.put(HiveLoanDueReminderRepository.keyName, '[1,2,3]');
      final loaded = await repo.load();
      expect(loaded, LoanDueReminderSettings.defaults());
    });

    test('キー欠落 JSON は既定値へフォールバック', () async {
      final repo = HiveLoanDueReminderRepository();
      final box =
          await Hive.openBox<String>(HiveLoanDueReminderRepository.boxName);
      await box.put(HiveLoanDueReminderRepository.keyName, '{"enabled":true}');
      final loaded = await repo.load();
      expect(loaded, LoanDueReminderSettings.defaults());
    });
  });
}
