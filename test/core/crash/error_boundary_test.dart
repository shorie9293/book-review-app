import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/crash/crash_log_repository.dart';
import 'package:book_review_app/core/crash/crash_log_service.dart';
import 'package:book_review_app/core/crash/error_boundary.dart';

void main() {
  late InMemoryCrashLogRepository repository;
  late CrashLogger logger;
  late Widget Function(FlutterErrorDetails) originalBuilder;

  setUp(() {
    repository = InMemoryCrashLogRepository();
    logger = CrashLogger(repository, clock: () => DateTime(2026, 1, 1, 12));
    originalBuilder = ErrorWidget.builder;
  });

  tearDown(() {
    ErrorWidget.builder = originalBuilder;
  });

  /// build 中に例外を投げる子。
  Widget throwingChild() => Builder(
        builder: (context) => throw StateError('build失敗'),
      );

  /// build のたびに呼ばれるカウンタ付きの子。
  Widget countingChild(int Function() onBuild) => Builder(
        builder: (context) {
          onBuild();
          return const Text('復帰しました');
        },
      );

  testWidgets('子の build 例外を捕捉し、日本語の復帰UIを出す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(logger: logger, child: throwingChild()),
      ),
    );
    while (tester.takeException() != null) {}

    expect(find.byKey(ErrorBoundary.fallbackKey), findsOneWidget);
    expect(find.text('表示中に問題が発生しました'), findsOneWidget);
    expect(find.text('再読み込み'), findsOneWidget);

    await tester.pump();
    final entries = await repository.loadAll();
    expect(entries.length, 1);
    expect(entries.single.kind, 'widget');
    expect(entries.single.message, contains('build失敗'));
  });

  testWidgets('再読み込みで子を作り直す（世代が進む）', (tester) async {
    var builds = 0;
    var shouldThrow = true;

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          logger: logger,
          child: Builder(
            builder: (context) {
              builds++;
              if (shouldThrow) throw StateError('build失敗');
              return const Text('復帰しました');
            },
          ),
        ),
      ),
    );
    while (tester.takeException() != null) {}
    expect(builds, 1);

    shouldThrow = false;
    await tester.tap(find.byKey(ErrorBoundary.reloadKey));
    await tester.pump();

    expect(builds, 2);
    expect(find.text('復帰しました'), findsOneWidget);
    expect(find.byKey(ErrorBoundary.fallbackKey), findsNothing);
  });

  testWidgets('初期化時に ErrorWidget.builder を差し替え、dispose で戻す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(logger: logger, child: countingChild(() => 0)),
      ),
    );
    expect(identical(ErrorWidget.builder, originalBuilder), isFalse);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(identical(ErrorWidget.builder, originalBuilder), isTrue);
  });

  testWidgets('Semantics ラベル付き（読み上げ可能）', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(logger: logger, child: throwingChild()),
      ),
    );
    while (tester.takeException() != null) {}

    expect(
      find.bySemanticsLabel(RegExp('表示中に問題が発生しました。再読み込みできます')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
