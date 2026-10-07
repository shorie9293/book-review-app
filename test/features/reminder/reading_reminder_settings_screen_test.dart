import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reminder/data/reading_reminder_repository.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/reading_reminder_scheduler.dart';
import 'package:book_review_app/features/reminder/presentation/reading_reminder_settings_screen.dart';

/// 呼び出しを記録するフェイクスケジューラ。
class FakeReadingReminderScheduler implements ReadingReminderScheduler {
  final List<String> calls = [];
  ReadingReminderSettings? lastApplied;

  @override
  Future<void> apply(ReadingReminderSettings s) async {
    calls.add('apply');
    lastApplied = s;
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
  }

  @override
  Future<void> sendTestNotification() async {
    calls.add('sendTestNotification');
  }
}

Future<void> pumpScreen(
  WidgetTester tester, {
  InMemoryReadingReminderRepository? repository,
  FakeReadingReminderScheduler? scheduler,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReadingReminderSettingsScreen(
        repository: repository ?? InMemoryReadingReminderRepository(),
        scheduler: scheduler ?? FakeReadingReminderScheduler(),
        now: () => DateTime(2026, 10, 8, 9, 0),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('読書リマインダー設定画面', () {
    testWidgets('既定ロード: スイッチ OFF・次回ラベルは「通知は無効です」', (tester) async {
      await pumpScreen(tester);

      final switchTile = tester.widget<SwitchListTile>(
        find.byKey(AppKeys.readingReminderEnabledSwitch),
      );
      expect(switchTile.value, isFalse);
      final label = tester.widget<Text>(
        find.byKey(AppKeys.readingReminderNextLabel),
      );
      expect(label.data, '通知は無効です');
    });

    testWidgets('スイッチ ON で次回ラベルに日時（yyyy/MM/dd HH:mm）が出る', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(AppKeys.readingReminderEnabledSwitch));
      await tester.pumpAndSettle();

      final label = tester.widget<Text>(
        find.byKey(AppKeys.readingReminderNextLabel),
      );
      expect(label.data, matches(RegExp(r'^\d{4}/\d{2}/\d{2} \d{2}:\d{2}$')));
    });

    testWidgets('曜日チップのタップで選択が変わる', (tester) async {
      final repository = InMemoryReadingReminderRepository();
      await pumpScreen(tester, repository: repository);

      // 既定は月〜日全選択。土（6）をタップして解除する。
      await tester.tap(find.byKey(AppKeys.readingReminderWeekdayChip(6)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.readingReminderSaveButton));
      await tester.pumpAndSettle();

      final saved = await repository.load();
      expect(saved.weekdays, [1, 2, 3, 4, 5, 7]);
    });

    testWidgets('保存ボタンで repository.save と scheduler.apply が呼ばれる', (tester) async {
      final repository = InMemoryReadingReminderRepository();
      final scheduler = FakeReadingReminderScheduler();
      await pumpScreen(tester, repository: repository, scheduler: scheduler);

      await tester.tap(find.byKey(AppKeys.readingReminderEnabledSwitch));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.readingReminderSaveButton));
      await tester.pumpAndSettle();

      expect(scheduler.calls, contains('apply'));
      // 永続化まで到達していること（保存後のリポジトリ値を直接検証）。
      final persisted = await repository.load();
      expect(persisted.enabled, isTrue);
      expect(find.text('保存しました'), findsOneWidget);
    });

    testWidgets('テスト通知ボタンで scheduler.sendTestNotification が呼ばれる',
        (tester) async {
      final scheduler = FakeReadingReminderScheduler();
      await pumpScreen(tester, scheduler: scheduler);

      await tester.tap(find.byKey(AppKeys.readingReminderTestButton));
      await tester.pumpAndSettle();

      expect(scheduler.calls, contains('sendTestNotification'));
    });
  });
}
