import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:book_review_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('basic smoke test', (WidgetTester tester) async {
    // 正規の起動経路（Hive 初期化・通知・自動バックアップ配線）を通す。
    // 通知プラグイン等の失敗は bootstrap 側で try/catch 済み。
    await app.bootstrap();

    // 起動直後は初期化中でアニメーションが続くため pumpAndSettle は使わない。
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // 起動配線の検証: runApp まで到達していれば MaterialApp が1つ存在する。
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
