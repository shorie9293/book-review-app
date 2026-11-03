import 'package:flutter/foundation.dart';

/// ログの出力先（試練で差し替え可能にするための抽象）。
typedef LogSink = void Function(String message);

/// 本番で冗長ログを垂れ流さないための唯一のログ入口。
///
/// - [debug] / [info] は debug ビルドのみ出力する（release では無出力）。
/// - [warn] / [error] は障害調査のために常時出力する。
/// - sink が例外を投げてもアプリを落とさない（ログは本質ではない）。
class AppLogger {
  AppLogger({bool? isDebug, LogSink? sink})
      : isDebug = isDebug ?? kDebugMode,
        _sink = sink ?? debugPrint;

  /// debug ビルドか（既定は [kDebugMode]）。
  final bool isDebug;

  final LogSink _sink;

  /// 開発時のみ残す詳細ログ。
  void debug(String message) {
    if (!isDebug) return;
    _emit('DEBUG', message, null, null);
  }

  /// 開発時のみ残す情報ログ。
  void info(String message) {
    if (!isDebug) return;
    _emit('INFO', message, null, null);
  }

  /// 回復可能な失敗（フォールバックした・通知できなかった等）。
  void warn(String message, [Object? error, StackTrace? stackTrace]) {
    _emit('WARN', message, error, stackTrace);
  }

  /// 回復不能・要調査の失敗。
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _emit('ERROR', message, error, stackTrace);
  }

  void _emit(
    String level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final buffer = StringBuffer('[$level] $message');
    if (error != null) buffer.write(' | $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    try {
      _sink(buffer.toString());
    } catch (_) {
      // ログ出力の失敗でアプリを止めない。
    }
  }
}

/// アプリ全体で共有するロガー。
final appLog = AppLogger();
