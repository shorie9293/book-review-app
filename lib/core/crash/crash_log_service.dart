import 'dart:async';

import 'package:book_review_app/core/crash/crash_log_entry.dart';
import 'package:book_review_app/core/crash/crash_log_repository.dart';

/// クラッシュログの記録役。
///
/// [record] は投げっぱなし。保存の失敗も例外も外へ漏らさない
/// （ログの記録でアプリを壊さない）。
class CrashLogger {
  /// 追記先。
  final CrashLogRepository repository;

  /// 時刻の供給（試練で固定する）。
  final DateTime Function() clock;

  CrashLogger(this.repository, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  /// 1件を記録する（戻り値なし・例外なし）。
  void record(
    Object error,
    StackTrace? stack, {
    String kind = 'zone',
  }) {
    try {
      final entry = CrashLogEntry.capture(
        timestamp: clock(),
        kind: kind,
        error: error,
        stack: stack,
      );
      unawaited(_appendQuietly(entry));
    } catch (_) {
      // 組み立てに失敗しても黙る。
    }
  }

  Future<void> _appendQuietly(CrashLogEntry entry) async {
    try {
      await repository.append(entry);
    } catch (_) {
      // 保存に失敗しても黙る。
    }
  }
}

/// 既定の保存先（差し替え可能。試練や将来の設定画面から使う）。
CrashLogRepository _defaultRepository = FileCrashLogRepository();

/// 既定の保存先を得る。
CrashLogRepository get defaultCrashLogRepository => _defaultRepository;

/// 既定の保存先を差し替える（試練用フック）。
void overrideDefaultCrashLogRepository(CrashLogRepository repository) {
  _defaultRepository = repository;
}

/// 既定の保存先を使う記録役。
CrashLogger defaultCrashLogger() => CrashLogger(defaultCrashLogRepository);

/// 0件なら null、あれば「前回の異常終了 N件（最終 HH:mm）」。
///
/// 純粋関数。表示文言の決定だけを行う。
String? summarize(List<CrashLogEntry> entries, {DateTime? now}) {
  if (entries.isEmpty) return null;
  DateTime latest = entries.first.timestamp;
  for (final entry in entries) {
    if (entry.timestamp.isAfter(latest)) latest = entry.timestamp;
  }
  final local = latest.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '前回の異常終了 ${entries.length}件（最終 $hh:$mm）';
}

/// 新しい順に [limit] 件だけ返す。
List<CrashLogEntry> recent(
  List<CrashLogEntry> entries, {
  int limit = 10,
}) {
  if (limit <= 0) return const <CrashLogEntry>[];
  final sorted = List<CrashLogEntry>.of(entries)
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  if (sorted.length <= limit) return sorted;
  return sorted.sublist(0, limit);
}
