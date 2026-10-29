import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/settings/presentation/settings_hub_screen.dart';

void main() {
  testWidgets('設定ハブに自動バックアップの導線が1本だけある', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsHubScreen()));

    final entry = find.byKey(AppKeys.settingsHubItem('auto_backup'));
    await tester.scrollUntilVisible(
      entry,
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(entry, findsOneWidget);
    expect(find.text('自動バックアップ'), findsOneWidget);
  });

  testWidgets('タップで注入したビルダーが開く', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsHubScreen(
          autoBackupBuilder: (context) {
            calls++;
            return const Scaffold(body: Center(child: Text('auto_backup_body')));
          },
        ),
      ),
    );

    final entry = find.byKey(AppKeys.settingsHubItem('auto_backup'));
    await tester.scrollUntilVisible(
      entry,
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('auto_backup_body'), findsOneWidget);
  });
}
