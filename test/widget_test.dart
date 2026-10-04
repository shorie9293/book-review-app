import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/features/tutorial/data/tutorial_repository.dart';
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
      await Hive.deleteBoxFromDisk(HiveTutorialRepository.boxName);
    } catch (_) {}
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// FakeAsync 下では dart:io の非同期が完結しないため、
  /// チュートリアル用ボックスを実時間で事前に開く。
  Future<void> preOpenTutorialBox(WidgetTester tester) {
    return tester.runAsync(
      () => Hive.openBox<bool>(HiveTutorialRepository.boxName),
    );
  }

  testWidgets('アプリが起動して読み込み中・本棚・チュートリアルのいずれかが表示される', (WidgetTester tester) async {
    await preOpenTutorialBox(tester);
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // MainScreen shows loading spinner, bookshelf screen, or tutorial screen
    final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasScaffold = find.byKey(const Key('screen_bookshelf')).evaluate().isNotEmpty;
    final hasTutorial = find.byKey(const Key('screen_tutorial')).evaluate().isNotEmpty;

    expect(hasLoading || hasScaffold || hasTutorial, isTrue);
  });

  testWidgets('チュートリアル未完了の初回起動ではチュートリアルが表示される', (WidgetTester tester) async {
    await preOpenTutorialBox(tester);
    await tester.pumpWidget(const MyApp());
    // ゲートの非同期確認を待つ
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final hasTutorial = find.byKey(const Key('screen_tutorial')).evaluate().isNotEmpty;
    expect(hasTutorial, isTrue);
  });
}
