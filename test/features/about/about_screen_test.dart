import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/about/domain/about_info.dart';
import 'package:book_review_app/features/about/presentation/about_screen.dart';

void main() {
  final info = AboutInfo(
    appName: 'テストアプリ',
    version: '9.9.9',
    contactEmail: 'test@example.com',
    privacyPolicyUrl: 'https://example.com/privacy',
    tagline: '試練用タグライン',
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AboutScreen(
          info: info,
          // 外部遷移の既定実装は端末プラグインに触れるため、試練では
          // 常に失敗するフェイクを注入してコピー導線側を検証する。
          urlOpener: (_) async => false,
        ),
      ),
    );
  }

  testWidgets('アプリ名とv<version>を表示する', (tester) async {
    await pump(tester);
    expect(find.text('テストアプリ'), findsOneWidget);
    expect(find.text('v9.9.9'), findsOneWidget);
    expect(find.text('試練用タグライン'), findsOneWidget);
  });

  testWidgets('OSSライセンスを押すと LicensePage が開く', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('about_license_button')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('テストアプリ'), findsWidgets);
  });

  testWidgets('プライバシーを押すとURL入りダイアログが開く', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('about_privacy_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('https://example.com/privacy'), findsWidgets);
  });

  testWidgets('プライバシーURLのコピーでSnackBarを出す', (tester) async {
    final copied = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AboutScreen(
          info: info,
          clipboardWriter: (value) async => copied.add(value),
          urlOpener: (_) async => false,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('about_privacy_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about_copy_button')));
    await tester.pumpAndSettle();
    expect(copied, ['https://example.com/privacy']);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('プライバシーポリシーURLをクリップボードにコピーしました'), findsOneWidget);
  });

  testWidgets('コピー失敗でもクラッシュせず失敗SnackBarを出す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AboutScreen(
          info: info,
          clipboardWriter: (value) async => throw StateError('clipboard'),
          urlOpener: (_) async => false,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('about_privacy_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about_copy_button')));
    await tester.pumpAndSettle();
    expect(find.text('コピーに失敗しました'), findsOneWidget);
  });

  testWidgets('問い合わせでメールアドレス入りダイアログが開く', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('about_contact_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('test@example.com'), findsWidgets);
  });
}
