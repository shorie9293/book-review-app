import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reminder/data/quiet_hours_repository.dart';
import 'package:book_review_app/features/reminder/data/reading_reminder_repository.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_settings.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/reading_reminder_scheduler.dart';
import 'package:book_review_app/features/reminder/presentation/quiet_hours_settings_screen.dart';
import 'package:book_review_app/features/reminder/presentation/reading_reminder_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 呼び出しを記録しない最小フェイク（画面のビルドにのみ必要）。
class FakeReadingReminderScheduler implements ReadingReminderScheduler {
  @override
  Future<void> apply(ReadingReminderSettings s) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> sendTestNotification() async {}
}

/// ローディング中の不確定アニメーションで止まらないよう、
/// pumpAndSettle ではなく pump + pump(Duration) で進める。
Future<void> pumpQuietHours(
  WidgetTester tester, {
  QuietHoursRepository? repository,
  DateTime? now,
  ValueChanged<QuietHoursSettings>? onSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: QuietHoursSettingsScreen(
        repository: repository ?? InMemoryQuietHoursRepository(),
        now: now ?? DateTime(2026, 10, 8, 9, 0),
        onSaved: onSaved,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

String previewText(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(AppKeys.quietHoursPreview));
  return text.data ?? '';
}

void main() {
  group('静穏時間設定画面', () {
    testWidgets('既定値: 無効・プレビューは「静穏時間は無効です」', (tester) async {
      await pumpQuietHours(tester);

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(AppKeys.quietHoursToggle),
      );
      expect(toggle.value, isFalse);
      expect(previewText(tester), '静穏時間は無効です');
      // 無効時は時刻・方針の入力は出さない。
      expect(find.byKey(AppKeys.quietHoursStartHour), findsNothing);
    });

    testWidgets('有効化で時刻入力と方針ラジオが出る', (tester) async {
      await pumpQuietHours(tester);

      await tester.tap(find.byKey(AppKeys.quietHoursToggle));
      await tester.pump();

      expect(find.byKey(AppKeys.quietHoursStartHour), findsOneWidget);
      expect(find.byKey(AppKeys.quietHoursEndMinute), findsOneWidget);
      expect(
        find.byKey(AppKeys.quietHoursPolicyRadio('defer')),
        findsOneWidget,
      );
      expect(
        find.byKey(AppKeys.quietHoursPolicyRadio('skip')),
        findsOneWidget,
      );
    });

    testWidgets('defer 既定のプレビューは翌朝への繰延を説明する', (tester) async {
      await pumpQuietHours(tester);

      await tester.tap(find.byKey(AppKeys.quietHoursToggle));
      await tester.pump();

      expect(previewText(tester), '22:00〜07:00 の通知は翌朝 07:00 に繰り延べます');
    });

    testWidgets('skip を選ぶとプレビューが「行いません」に変わる', (tester) async {
      await pumpQuietHours(
        tester,
        repository: InMemoryQuietHoursRepository(
          QuietHoursSettings(enabled: true),
        ),
      );

      await tester.tap(find.byKey(AppKeys.quietHoursPolicyRadio('skip')));
      await tester.pump();

      expect(previewText(tester), '22:00〜07:00 の通知は行いません');
    });

    testWidgets('start == end は抑止なしと案内する', (tester) async {
      await pumpQuietHours(
        tester,
        repository: InMemoryQuietHoursRepository(
          QuietHoursSettings(enabled: true, startHour: 22, endHour: 22),
        ),
      );

      expect(previewText(tester), '開始と終了が同じため通知は抑止されません');
    });

    testWidgets('静穏時間内の現在時刻なら「ただいま静穏時間内です」', (tester) async {
      await pumpQuietHours(
        tester,
        repository: InMemoryQuietHoursRepository(
          QuietHoursSettings(enabled: true),
        ),
        now: DateTime(2026, 10, 8, 23, 30),
      );

      expect(find.text('ただいま静穏時間内です'), findsOneWidget);
    });

    testWidgets('静穏時間外の現在時刻なら「ただいま静穏時間外です」', (tester) async {
      await pumpQuietHours(
        tester,
        repository: InMemoryQuietHoursRepository(
          QuietHoursSettings(enabled: true),
        ),
        now: DateTime(2026, 10, 8, 12, 0),
      );

      expect(find.text('ただいま静穏時間外です'), findsOneWidget);
    });

    testWidgets('保存でリポジトリへ到達し、コールバックと通知が出る', (tester) async {
      final repository = InMemoryQuietHoursRepository();
      QuietHoursSettings? notified;
      await pumpQuietHours(
        tester,
        repository: repository,
        onSaved: (s) => notified = s,
      );

      await tester.tap(find.byKey(AppKeys.quietHoursToggle));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.quietHoursSaveButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.saveCount, 1);
      final persisted = await repository.load();
      expect(persisted.enabled, isTrue);
      expect(notified, persisted);
      expect(find.text('静穏時間を保存しました'), findsOneWidget);
    });

    testWidgets('既存設定（skip・有効）が復元される', (tester) async {
      await pumpQuietHours(
        tester,
        repository: InMemoryQuietHoursRepository(
          QuietHoursSettings(enabled: true, policy: QuietHoursPolicy.skip),
        ),
      );

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(AppKeys.quietHoursToggle),
      );
      expect(toggle.value, isTrue);
      expect(previewText(tester), contains('行いません'));
    });
  });

  group('読書リマインダー設定画面からの導線', () {
    Future<void> pumpReminder(
      WidgetTester tester, {
      QuietHoursRepository? quietHoursRepository,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingReminderSettingsScreen(
            repository: InMemoryReadingReminderRepository(),
            scheduler: FakeReadingReminderScheduler(),
            now: () => DateTime(2026, 10, 8, 9, 0),
            quietHoursRepository: quietHoursRepository,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('未注入なら導線を出さない（既存試練の無破壊）', (tester) async {
      await pumpReminder(tester);
      expect(find.byKey(AppKeys.quietHoursEntry), findsNothing);
    });

    testWidgets('注入時は導線が出て、タップで静穏時間画面へ遷移する', (tester) async {
      await pumpReminder(
        tester,
        quietHoursRepository: InMemoryQuietHoursRepository(),
      );

      expect(find.byKey(AppKeys.quietHoursEntry), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.quietHoursEntry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(QuietHoursSettingsScreen), findsOneWidget);
      expect(find.byKey(AppKeys.quietHoursScreen), findsOneWidget);
    });
  });
}
