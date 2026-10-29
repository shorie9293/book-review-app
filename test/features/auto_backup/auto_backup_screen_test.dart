import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:book_review_app/features/auto_backup/presentation/auto_backup_screen.dart';

class _FakeRestorer implements AutoBackupRestorer {
  final List<String> calls = [];
  final bool ok;
  final String message;

  _FakeRestorer({this.ok = true, this.message = '復元しました'});

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    calls.add(fileName);
    return AutoBackupRestoreResult(
      ok: ok,
      message: message,
      safetyFileName: 'auto_backup_20261029.json',
    );
  }
}

class _ThrowingRestorer implements AutoBackupRestorer {
  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    throw StateError('boom');
  }
}

class _FakeSharer implements AutoBackupSharer {
  final List<String> files = [];
  final List<String> bodies = [];

  @override
  Future<void> share(String fileName, String json) async {
    files.add(fileName);
    bodies.add(json);
  }
}

InMemoryAutoBackupStore _store() {
  final store = InMemoryAutoBackupStore(now: () => DateTime(2026, 10, 29));
  store.seed(
    fileName: 'auto_backup_20261027.json',
    createdAt: DateTime(2026, 10, 27, 6, 5),
    contents: '{"schemaVersion":1,"books":[]}',
  );
  store.seed(
    fileName: 'auto_backup_20261029.json',
    createdAt: DateTime(2026, 10, 29, 7, 12),
    contents: '{"schemaVersion":1}',
  );
  return store;
}

Widget _wrap(Widget child) => MaterialApp(home: child);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('AutoBackupScreen', () {
    testWidgets('新しい順に一覧表示し、保持ラベルを出す', (tester) async {
      await tester.pumpWidget(
        _wrap(AutoBackupScreen(store: _store())),
      );
      await _settle(tester);

      final newest = find.byKey(AppKeys.autoBackupRow('auto_backup_20261029.json'));
      final oldest = find.byKey(AppKeys.autoBackupRow('auto_backup_20261027.json'));
      expect(newest, findsOneWidget);
      expect(oldest, findsOneWidget);
      expect(
        tester.getTopLeft(newest).dy,
        lessThan(tester.getTopLeft(oldest).dy),
      );
      expect(find.text('保持 3世代中 2件'), findsOneWidget);
    });

    testWidgets('0件なら空状態を出す', (tester) async {
      await tester.pumpWidget(
        _wrap(AutoBackupScreen(store: InMemoryAutoBackupStore())),
      );
      await _settle(tester);

      expect(find.byKey(AppKeys.autoBackupEmpty), findsOneWidget);
      expect(find.text('バックアップはまだありません'), findsOneWidget);
    });

    testWidgets('壊れた JSON の世代は一覧に出さない', (tester) async {
      final store = _store();
      store.seed(
        fileName: 'auto_backup_20261028.json',
        createdAt: DateTime(2026, 10, 28, 7),
        contents: 'broken',
      );

      await tester.pumpWidget(_wrap(AutoBackupScreen(store: store)));
      await _settle(tester);

      expect(
        find.byKey(AppKeys.autoBackupRow('auto_backup_20261028.json')),
        findsNothing,
      );
      expect(
        find.byKey(AppKeys.autoBackupRow('auto_backup_20261029.json')),
        findsOneWidget,
      );
    });

    testWidgets('復元は確認ダイアログの OK で1回だけ呼ばれる', (tester) async {
      final restorer = _FakeRestorer();
      await tester.pumpWidget(
        _wrap(AutoBackupScreen(store: _store(), restorer: restorer)),
      );
      await _settle(tester);

      await tester.tap(
        find.byKey(AppKeys.autoBackupRestore('auto_backup_20261029.json')),
      );
      await _settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(restorer.calls, isEmpty);

      await tester.tap(find.byKey(AppKeys.autoBackupRestoreConfirm));
      await _settle(tester);

      expect(restorer.calls, ['auto_backup_20261029.json']);
      expect(find.text('復元しました'), findsOneWidget);
    });

    testWidgets('確認ダイアログのキャンセルでは呼ばれない', (tester) async {
      final restorer = _FakeRestorer();
      await tester.pumpWidget(
        _wrap(AutoBackupScreen(store: _store(), restorer: restorer)),
      );
      await _settle(tester);

      await tester.tap(
        find.byKey(AppKeys.autoBackupRestore('auto_backup_20261029.json')),
      );
      await _settle(tester);
      await tester.tap(find.byKey(AppKeys.autoBackupRestoreCancel));
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(restorer.calls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('restorer/sharer 未注入なら導線を出さない', (tester) async {
      await tester.pumpWidget(_wrap(AutoBackupScreen(store: _store())));
      await _settle(tester);

      expect(
        find.byKey(AppKeys.autoBackupRestore('auto_backup_20261029.json')),
        findsNothing,
      );
      expect(
        find.byKey(AppKeys.autoBackupShare('auto_backup_20261029.json')),
        findsNothing,
      );
    });

    testWidgets('共有は sharer 注入時のみ・内容を渡す', (tester) async {
      final sharer = _FakeSharer();
      await tester.pumpWidget(
        _wrap(AutoBackupScreen(store: _store(), sharer: sharer)),
      );
      await _settle(tester);

      await tester.tap(
        find.byKey(AppKeys.autoBackupShare('auto_backup_20261029.json')),
      );
      await _settle(tester);

      expect(sharer.files, ['auto_backup_20261029.json']);
      expect(sharer.bodies, ['{"schemaVersion":1}']);
      expect(find.text('バックアップを共有しました'), findsOneWidget);
    });

    testWidgets('復元の例外は握って SnackBar に出す', (tester) async {
      await tester.pumpWidget(
        _wrap(AutoBackupScreen(store: _store(), restorer: _ThrowingRestorer())),
      );
      await _settle(tester);

      await tester.tap(
        find.byKey(AppKeys.autoBackupRestore('auto_backup_20261029.json')),
      );
      await _settle(tester);
      await tester.tap(find.byKey(AppKeys.autoBackupRestoreConfirm));
      await _settle(tester);

      expect(find.text('復元に失敗しました'), findsOneWidget);
    });

    testWidgets('復元の失敗結果も文言どおり SnackBar に出す', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AutoBackupScreen(
            store: _store(),
            restorer: _FakeRestorer(ok: false, message: '復元できません'),
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(
        find.byKey(AppKeys.autoBackupRestore('auto_backup_20261029.json')),
      );
      await _settle(tester);
      await tester.tap(find.byKey(AppKeys.autoBackupRestoreConfirm));
      await _settle(tester);

      expect(find.text('復元できません'), findsOneWidget);
    });

    testWidgets('onBackupNow ボタンは注入時のみ・タップで呼ばれる', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          AutoBackupScreen(
            store: _store(),
            onBackupNow: () async => calls++,
          ),
        ),
      );
      await _settle(tester);

      expect(find.byKey(AppKeys.autoBackupNow), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.autoBackupNow));
      await _settle(tester);

      expect(calls, 1);

      await tester.pumpWidget(_wrap(AutoBackupScreen(store: _store())));
      await _settle(tester);
      expect(find.byKey(AppKeys.autoBackupNow), findsNothing);
    });
  });
}
