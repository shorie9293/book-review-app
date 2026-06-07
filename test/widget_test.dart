import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/main.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('books');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('アプリが起動して読み込み中または本棚が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // MainScreen shows loading spinner or bookshelf screen
    final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasScaffold = find.byKey(const Key('screen_bookshelf')).evaluate().isNotEmpty;

    expect(hasLoading || hasScaffold, isTrue);
  });
}
