import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reminder/data/reading_reminder_repository.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/reading_reminder_scheduler.dart';
import 'package:book_review_app/features/reminder/presentation/reading_reminder_settings_screen.dart';

/// 親探針用の記録フェイク。
class ProbeScheduler implements ReadingReminderScheduler {
  final List<String> calls = [];
  ReadingReminderSettings? lastApplied;

  @override
  Future<void> apply(ReadingReminderSettings s) async {
    calls.add('apply');
    lastApplied = s;
  }

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Future<void> sendTestNotification() async => calls.add('sendTestNotification');
}

Future<void> pumpProbe(
  WidgetTester tester, {
  required ReadingReminderRepository repository,
  ReadingReminderScheduler? scheduler,
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReadingReminderSettingsScreen(
        repository: repository,
        scheduler: scheduler ?? ProbeScheduler(),
        now: now ?? () => DateTime(2026, 10, 8, 9, 0),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('親探針: 読書リマインダーの合成不変条件', () {
    testWidgets('画面Aで保存した設定が別画面インスタンスで復元される（永続化到達）',
        (tester) async {
      final repo = InMemoryReadingReminderRepository();

      await pumpProbe(tester, repository: repo);
      await tester.tap(find.byKey(AppKeys.readingReminderEnabledSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.readingReminderSaveButton));
      await tester.pumpAndSettle();

      // 別インスタンス（同一リポジトリ）で復元されるか。
      await pumpProbe(tester, repository: repo);
      final switchTile = tester.widget<SwitchListTile>(
        find.byKey(AppKeys.readingReminderEnabledSwitch),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('曜日の追加後も永続化される weekdays は昇順ユニーク', (tester) async {
      final repo = InMemoryReadingReminderRepository(
        ReadingReminderSettings(enabled: true, weekdays: const [6, 1]),
      );

      await pumpProbe(tester, repository: repo);
      // 水（3）を追加選択する。
      await tester.tap(find.byKey(AppKeys.readingReminderWeekdayChip(3)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.readingReminderSaveButton));
      await tester.pumpAndSettle();

      final persisted = await repo.load();
      expect(persisted.weekdays, [1, 3, 6]);
    });

    testWidgets('次回ラベルは純粋サービス nextOccurrence と一致する（縫ぎ目）',
        (tester) async {
      final repo = InMemoryReadingReminderRepository(
        ReadingReminderSettings(
          enabled: true,
          hour: 7,
          minute: 30,
          weekdays: const [3],
        ),
      );
      // 2026-10-08 は木曜。直近の水曜は 2026-10-14。
      await pumpProbe(
        tester,
        repository: repo,
        now: () => DateTime(2026, 10, 8, 9, 0),
      );

      final label = tester.widget<Text>(
        find.byKey(AppKeys.readingReminderNextLabel),
      );
      expect(label.data, '2026/10/14 07:30');
    });

    testWidgets('通知日が空なら空メッセージを出し、空のまま永続化される',
        (tester) async {
      final repo = InMemoryReadingReminderRepository(
        ReadingReminderSettings(enabled: true, weekdays: const []),
      );

      await pumpProbe(tester, repository: repo);
      final label = tester.widget<Text>(
        find.byKey(AppKeys.readingReminderNextLabel),
      );
      expect(label.data, '通知日が未選択です');

      await tester.tap(find.byKey(AppKeys.readingReminderSaveButton));
      await tester.pumpAndSettle();

      final persisted = await repo.load();
      expect(persisted.weekdays, isEmpty);
      expect(persisted.enabled, isTrue);
    });
  });
}
