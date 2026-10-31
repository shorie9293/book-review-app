import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/widgets/load_state_views.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );
    await tester.pumpAndSettle();
  }

  group('LoadErrorView', () {
    testWidgets('message と再試行ボタンを表示する', (tester) async {
      var retried = 0;
      await pump(
        tester,
        LoadErrorView(message: '読み込みに失敗しました', onRetry: () => retried++),
      );

      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.text('読み込みに失敗しました'), findsOneWidget);
      expect(find.byKey(const ValueKey('load_retry_button')), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);

      // 空状態ウィジェットは出ない（失敗と0件の分離）
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('onRetry が null なら再試行ボタンを出さない', (tester) async {
      await pump(tester, const LoadErrorView(message: '復元できない記録があります'));

      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.text('復元できない記録があります'), findsOneWidget);
      expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
      expect(find.text('再試行'), findsNothing);
    });
  });

  group('LoadEmptyView', () {
    testWidgets('message を表示し、失敗表示は出さない', (tester) async {
      await pump(tester, const LoadEmptyView(message: 'まだ記録がありません'));

      expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
      expect(find.text('まだ記録がありません'), findsOneWidget);
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
    });

    testWidgets('文言は error と empty で必ず異なる', (tester) async {
      await pump(tester, const LoadEmptyView(message: 'まだ記録がありません'));
      expect(find.text('まだ記録がありません'), findsOneWidget);

      await pump(tester, const LoadErrorView(message: '読み込みに失敗しました'));
      expect(find.text('まだ記録がありません'), findsNothing);
      expect(find.text('読み込みに失敗しました'), findsOneWidget);
    });
  });
}
