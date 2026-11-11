// 連携状況画面の試練。
//
// 「未記録」で終わらせず、成否・時刻・件数・ファイル名・失敗理由まで
// 1画面で分かることを固定する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:book_review_app/core/infrastructure/app_lock_settings_screen.dart';
import 'package:book_review_app/core/infrastructure/cross_app_link_status.dart';
import 'package:book_review_app/core/infrastructure/cross_app_link_status_store.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/settings/presentation/cross_app_link_status_screen.dart';
import 'package:book_review_app/features/settings/presentation/settings_hub_screen.dart';

CrossAppTransferRecord _rec({
  DateTime? at,
  bool ok = true,
  int count = 1,
  String? fileName,
  String? error,
}) =>
    CrossAppTransferRecord(
      at: at ?? DateTime(2026, 11, 11, 9, 5),
      ok: ok,
      count: count,
      fileName: fileName,
      error: error,
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

CrossAppLinkStatusRecorder _recorder(CrossAppLinkSnapshot snapshot) =>
    CrossAppLinkStatusRecorder(
      store: InMemoryCrossAppLinkStatusStore(snapshot),
      now: () => DateTime(2026, 11, 11, 9, 5),
    );

void main() {
  group('CrossAppLinkStatusScreen', () {
    testWidgets('記録が無ければ「未記録」と未設定を出す', (tester) async {
      await tester.pumpWidget(_wrap(
        CrossAppLinkStatusScreen(
            recorder: _recorder(CrossAppLinkSnapshot.empty)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('連携状況'), findsOneWidget);
      expect(find.text('未設定（連携は停止中）'), findsOneWidget);
      expect(find.text('未記録'), findsNWidgets(2));
    });

    testWidgets('記録があれば成否・時刻・件数・ファイル名を出す', (tester) async {
      await tester.pumpWidget(_wrap(
        CrossAppLinkStatusScreen(
          recorder: _recorder(
            CrossAppLinkSnapshot(
              lastSent:
                  _rec(count: 3, fileName: 'book_review_reward_events.jsonl'),
              lastReceived: _rec(count: 2, fileName: 'kozuchi_quest.json'),
              sharedFolderReady: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('設定済み'), findsOneWidget);
      expect(
        find.text('成功・2026/11/11 09:05・3件・book_review_reward_events.jsonl'),
        findsOneWidget,
      );
      expect(
        find.text('成功・2026/11/11 09:05・2件・kozuchi_quest.json'),
        findsOneWidget,
      );
      expect(find.text('未記録'), findsNothing);
    });

    testWidgets('失敗は成否だけでなく理由まで表示する', (tester) async {
      await tester.pumpWidget(_wrap(
        CrossAppLinkStatusScreen(
          recorder: _recorder(
            CrossAppLinkSnapshot(
              lastSent: _rec(
                ok: false,
                count: 0,
                fileName: 'book_review_reward_events.jsonl',
                error: 'SharedStorageException(write, x): no directory',
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '失敗・2026/11/11 09:05・0件・book_review_reward_events.jsonl',
        ),
        findsOneWidget,
      );
      expect(
        find.text('SharedStorageException(write, x): no directory'),
        findsOneWidget,
      );
    });

    testWidgets('refresh キーで最新の記録を読み直す', (tester) async {
      final store = InMemoryCrossAppLinkStatusStore();
      final recorder = CrossAppLinkStatusRecorder(
          store: store, now: () => DateTime(2026, 11, 11, 9, 5));
      await tester
          .pumpWidget(_wrap(CrossAppLinkStatusScreen(recorder: recorder)));
      await tester.pumpAndSettle();
      expect(find.text('未記録'), findsNWidgets(2));

      // 画面の外で記録が進む（送受信の実行）。
      await recorder.recordSent(count: 1, fileName: 'a.jsonl');

      await tester.tap(find.byKey(CrossAppLinkStatusScreen.refreshKey));
      await tester.pumpAndSettle();

      expect(find.text('成功・2026/11/11 09:05・1件・a.jsonl'), findsOneWidget);
      expect(find.text('未記録'), findsOneWidget);
    });

    testWidgets('遅延した読込中はインジケータ、完了後に本体が出る', (tester) async {
      final recorder = _recorder(CrossAppLinkSnapshot.empty);
      await tester
          .pumpWidget(_wrap(CrossAppLinkStatusScreen(recorder: recorder)));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(CrossAppLinkStatusScreen.sentKey), findsOneWidget);
    });
  });

  group('設定ハブからの導線', () {
    testWidgets('項目「連携状況（現世間の受け渡し）」から画面を開ける', (tester) async {
      await tester.pumpWidget(_wrap(
        SettingsHubScreen(
          crossAppLinkStatusScreenBuilder: (_) => const Scaffold(
            body: Center(child: Text('stub_cross_app_link')),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final item = find.byKey(AppKeys.settingsHubItem('cross_app_link'));
      await tester.scrollUntilVisible(item, 120,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      expect(find.text('連携状況（現世間の受け渡し）'), findsOneWidget);

      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(find.text('stub_cross_app_link'), findsOneWidget);
      // AppBar のアイコンは増やさない（この現世は AppBar アイコン飽和の実績）。
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('ビルダー未指定なら実画面（CrossAppLinkStatusScreen）が開く', (tester) async {
      // 既定の記録口は SharedPreferences を使うため、試練ではモックに差し替える。
      SharedPreferences.setMockInitialValues(<String, Object>{});
      CrossAppLinkStatusRecorder.reset();
      addTearDown(CrossAppLinkStatusRecorder.reset);

      await tester.pumpWidget(_wrap(const SettingsHubScreen()));
      await tester.pumpAndSettle();

      final item = find.byKey(AppKeys.settingsHubItem('cross_app_link'));
      await tester.scrollUntilVisible(item, 120,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();

      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(find.byType(CrossAppLinkStatusScreen), findsOneWidget);
    });

    testWidgets('既存項目（アプリロック）は従来どおり開ける', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsHubScreen()));
      await tester.pumpAndSettle();

      final item = find.byKey(AppKeys.settingsHubItem('app_lock'));
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(find.byType(AppLockSettingsScreen), findsOneWidget);
    });
  });
}
