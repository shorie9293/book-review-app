import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:book_review_app/features/auto_backup/presentation/auto_backup_screen.dart';

/// 設定の可否まで受け取れる復元器（新経路）。
class _OptionsRestorer implements AutoBackupRestorerWithOptions {
  final List<bool> includeSettingsCalls = [];

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) =>
      restoreWithOptions(fileName);

  @override
  Future<AutoBackupRestoreResult> restoreWithOptions(
    String fileName, {
    bool includeSettings = true,
  }) async {
    includeSettingsCalls.add(includeSettings);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

/// 設定の可否を持たない従来の復元器。
class _LegacyRestorer implements AutoBackupRestorer {
  final List<String> calls = [];

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    calls.add(fileName);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

InMemoryAutoBackupStore _store() {
  final store = InMemoryAutoBackupStore(now: () => DateTime(2026, 10, 29));
  store.seed(
    fileName: 'auto_backup_20261029.json',
    createdAt: DateTime(2026, 10, 29, 7, 12),
    contents: '{"schemaVersion":1}',
  );
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(
    find.byKey(AppKeys.autoBackupRestore('auto_backup_20261029.json')),
  );
  await _settle(tester);
}

void main() {
  testWidgets('復元確認に「設定も戻す」チェックが既定ONで出る', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
          home:
              AutoBackupScreen(store: _store(), restorer: _OptionsRestorer())),
    );
    await _settle(tester);
    await _openDialog(tester);

    final checkbox = find.byKey(AppKeys.autoBackupRestoreIncludeSettings);
    expect(checkbox, findsOneWidget);
    expect(find.text('設定も戻す（テーマ・文字サイズ）'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
  });

  testWidgets('既定のまま復元すると設定も戻す（includeSettings: true）', (tester) async {
    final restorer = _OptionsRestorer();
    await tester.pumpWidget(
      MaterialApp(home: AutoBackupScreen(store: _store(), restorer: restorer)),
    );
    await _settle(tester);
    await _openDialog(tester);
    await tester.tap(find.byKey(AppKeys.autoBackupRestoreConfirm));
    await _settle(tester);

    expect(restorer.includeSettingsCalls, <bool>[true]);
  });

  testWidgets('チェックを外すと設定を戻さない（includeSettings: false）', (tester) async {
    final restorer = _OptionsRestorer();
    await tester.pumpWidget(
      MaterialApp(home: AutoBackupScreen(store: _store(), restorer: restorer)),
    );
    await _settle(tester);
    await _openDialog(tester);

    await tester.tap(find.byKey(AppKeys.autoBackupRestoreIncludeSettings));
    await _settle(tester);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(AppKeys.autoBackupRestoreIncludeSettings),
          )
          .value,
      isFalse,
    );

    await tester.tap(find.byKey(AppKeys.autoBackupRestoreConfirm));
    await _settle(tester);

    expect(restorer.includeSettingsCalls, <bool>[false]);
  });

  testWidgets('従来の復元器ではチェックを出さず、従来経路で復元する', (tester) async {
    final restorer = _LegacyRestorer();
    await tester.pumpWidget(
      MaterialApp(home: AutoBackupScreen(store: _store(), restorer: restorer)),
    );
    await _settle(tester);
    await _openDialog(tester);

    expect(find.byKey(AppKeys.autoBackupRestoreIncludeSettings), findsNothing);

    await tester.tap(find.byKey(AppKeys.autoBackupRestoreConfirm));
    await _settle(tester);

    expect(restorer.calls, <String>['auto_backup_20261029.json']);
  });

  testWidgets('キャンセルすると設定の可否も渡さない', (tester) async {
    final restorer = _OptionsRestorer();
    await tester.pumpWidget(
      MaterialApp(home: AutoBackupScreen(store: _store(), restorer: restorer)),
    );
    await _settle(tester);
    await _openDialog(tester);
    await tester.tap(find.byKey(AppKeys.autoBackupRestoreCancel));
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(restorer.includeSettingsCalls, isEmpty);
  });
}
