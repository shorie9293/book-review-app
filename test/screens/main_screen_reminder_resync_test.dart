import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:book_review_app/features/loan/domain/loan_due_reminder_resync.dart';
import 'package:book_review_app/screens/main_screen.dart';

/// 起動時の再計算呼出回数だけを数える偽の窓口。
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_main_resync_');
    Hive.init(tempDir.path);
    // フェイク時間ではファイルI/Oが進まず初期化が完了しないため、
    // 起動時に開く箱を先に開いて openBox を解決済みにしておく。
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

  testWidgets('起動完了時に返却期限リマインダーの再計算が1回走る', (tester) async {
    final resync = _FakeResync();

    await tester.pumpWidget(
      MaterialApp(home: MainScreen(reminderResync: resync)),
    );
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 初期化完了（本棚表示）後に1回だけ再計算している
    expect(find.byKey(const Key('screen_bookshelf')), findsOneWidget);
    expect(resync.triggerCount, 1);
  });
}
