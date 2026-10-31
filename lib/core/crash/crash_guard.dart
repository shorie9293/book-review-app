import 'package:flutter/foundation.dart';

import 'package:book_review_app/core/crash/crash_log_service.dart';

bool _installed = false;

/// 未捕捉例外の受け皿を差し込む。
///
/// - [FlutterError.onError] に既存ハンドラがあれば保存して合流する
///   （既存があればそれだけを呼ぶ。無ければ既定の [FlutterError.presentError]）。
/// - [PlatformDispatcher.onError] も同様に合流し、false を返す
///   （false = アプリを落とさない）。
///
/// 二重設置は無害（2回目以降は記録役の差し替えのみ）。
void installCrashGuard({CrashLogger? logger}) {
  final crashLogger = logger ?? defaultCrashLogger();

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    crashLogger.record(details.exception, details.stack, kind: 'flutter');
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    crashLogger.record(error, stack, kind: 'platform');
    if (previousPlatformOnError != null) {
      previousPlatformOnError(error, stack);
    }
    return false;
  };

  _installed = true;
}

/// 設置済みか（試練の補助）。
bool get isCrashGuardInstalled => _installed;
