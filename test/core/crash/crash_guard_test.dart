import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/crash/crash_guard.dart';
import 'package:book_review_app/core/crash/crash_log_repository.dart';
import 'package:book_review_app/core/crash/crash_log_service.dart';

void main() {
  late InMemoryCrashLogRepository repository;
  late CrashLogger logger;
  late FlutterExceptionHandler? originalFlutterHandler;
  late ErrorCallback? originalPlatformHandler;

  setUp(() {
    repository = InMemoryCrashLogRepository();
    logger = CrashLogger(repository, clock: () => DateTime(2026, 1, 1, 12));
    originalFlutterHandler = FlutterError.onError;
    originalPlatformHandler = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = originalFlutterHandler;
    PlatformDispatcher.instance.onError = originalPlatformHandler;
  });

  test('FlutterError.onError を合流させ、既存ハンドラも呼ぶ', () async {
    var previousCalls = 0;
    FlutterError.onError = (details) => previousCalls++;

    installCrashGuard(logger: logger);
    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('report失敗')),
    );
    await Future<void>.delayed(Duration.zero);

    expect(previousCalls, 1);
    final entries = await repository.loadAll();
    expect(entries.length, 1);
    expect(entries.single.kind, 'flutter');
    expect(entries.single.message, contains('report失敗'));
    expect(isCrashGuardInstalled, isTrue);
  });

  test('既存ハンドラが無くても記録する（握りつぶさない）', () async {
    FlutterError.onError = null;

    installCrashGuard(logger: logger);
    FlutterError.reportError(
      FlutterErrorDetails(exception: ArgumentError('no handler')),
    );
    await Future<void>.delayed(Duration.zero);

    final entries = await repository.loadAll();
    expect(entries.length, 1);
    expect(entries.single.message, contains('no handler'));
  });

  test('PlatformDispatcher.onError を合流し、false を返す（落とさない）', () async {
    var previousCalls = 0;
    PlatformDispatcher.instance.onError = (error, stack) {
      previousCalls++;
      return false;
    };

    installCrashGuard(logger: logger);
    final handler = PlatformDispatcher.instance.onError!;
    final result =
        handler(StateError('platform失敗'), StackTrace.fromString('#0 a'));
    await Future<void>.delayed(Duration.zero);

    expect(result, isFalse);
    expect(previousCalls, 1);
    final entries = await repository.loadAll();
    expect(entries.length, 1);
    expect(entries.single.kind, 'platform');
    expect(entries.single.stackTop, '#0 a');
  });
}
