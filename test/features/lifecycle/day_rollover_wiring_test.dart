import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:book_review_app/features/lifecycle/domain/day_rollover_detector.dart';
import 'package:book_review_app/features/lifecycle/presentation/app_lifecycle_refresher.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_resync.dart';
import 'package:book_review_app/screens/main_screen.dart';

/// 再計算の呼出回数だけを数える偽の窓口。
class _FakeResync implements LoanDueReminderResync {
  int triggerCount = 0;

  @override
  Future<bool> trigger() async {
    triggerCount++;
    return true;
  }
}

/// MainScreen の起動時に開かれる Hive の箱。
const _boxNames = [
  'books',
  'reviews',
  'book_notes',
  'reading_queue',
  'book_loans',
  'loan_reminder_box',
];

/// 前面復帰を確実に届けるため、正規の遷移で背面へ落としてから resumed を送る。
Future<void> _simulateForegroundResume(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_day_rollover_');
    Hive.init(tempDir.path);
    for (final name in _boxNames) {
      await Hive.openBox<String>(name);
    }
  });

  tearDown(() async {
    for (final name in _boxNames) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // 後始末の失敗は無視する
      }
    }
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('前面復帰で日付が跨ぐと本棚が再読込され再計算が追加で1回走る', (tester) async {
    final resync = _FakeResync();
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 28, 9, 0));
    var epoch = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => AppLifecycleRefresher(
            detector: detector,
            now: () => DateTime(2026, 10, 29, 9, 0),
            onRollover: () async => setState(() => epoch++),
            child: MainScreen(reminderResync: resync, dayEpoch: epoch),
          ),
        ),
      ),
    );
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 起動時の再計算は1回だけ。
    expect(find.byKey(const Key('screen_bookshelf')), findsOneWidget);
    expect(resync.triggerCount, 1);

    await _simulateForegroundResume(tester);
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 日付跨ぎの再読込で、既存の再計算窓口がもう1回走る。
    expect(epoch, 1);
    expect(resync.triggerCount, 2);
    expect(find.byKey(const Key('screen_bookshelf')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
