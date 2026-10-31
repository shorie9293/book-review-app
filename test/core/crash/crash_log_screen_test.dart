import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/crash/crash_log_entry.dart';
import 'package:book_review_app/core/crash/crash_log_repository.dart';
import 'package:book_review_app/core/crash/crash_log_screen.dart';

void main() {
  late InMemoryCrashLogRepository repository;

  setUp(() {
    repository = InMemoryCrashLogRepository();
  });

  Future<void> seed(int count) async {
    for (var i = 0; i < count; i++) {
      await repository.append(
        CrashLogEntry(
          timestamp: DateTime(2026, 1, 1, 10, i % 60),
          kind: 'zone',
          message: '不具合$i',
          stackTop: '#0 main.dart:$i',
        ),
      );
    }
  }

  testWidgets('記録が無ければ空状態を出す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CrashLogScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(CrashLogScreen.emptyKey), findsOneWidget);
    expect(find.text('記録された不具合はありません'), findsOneWidget);
    expect(find.byKey(CrashLogScreen.copyKey), findsNothing);
  });

  testWidgets('サマリーと直近一覧を表示する', (tester) async {
    await seed(2);
    await tester.pumpWidget(
      MaterialApp(home: CrashLogScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('前回の異常終了 2件'), findsOneWidget);
    expect(find.text('不具合0'), findsOneWidget);
    expect(find.text('不具合1'), findsOneWidget);
    expect(find.byKey(CrashLogScreen.copyKey), findsOneWidget);
  });

  testWidgets('コピーでクリップボードへ書き出す', (tester) async {
    await seed(1);
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(home: CrashLogScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CrashLogScreen.copyKey));
    await tester.pumpAndSettle();

    final copy = calls.where((c) => c.method == 'Clipboard.setData').toList();
    expect(copy.length, 1);
    final data = (copy.single.arguments as Map)['text'] as String;
    expect(data, contains('不具合0'));
    expect(data, contains('#0 main.dart:0'));
    expect(find.text('クリップボードへコピーしました'), findsOneWidget);
  });
}
