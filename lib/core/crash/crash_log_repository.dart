import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:book_review_app/core/crash/crash_log_entry.dart';

/// クラッシュログの保存先（注入可能にするための抽象）。
abstract class CrashLogRepository {
  /// 保存済みの全件（古い順）。
  Future<List<CrashLogEntry>> loadAll();

  /// 1件追記する（上限超過分は古いものから捨てる）。
  Future<void> append(CrashLogEntry entry);

  /// 全消去する。
  Future<void> clear();
}

/// 末尾 [maxEntries] 件だけを残す共通ローテーション。
List<CrashLogEntry> rotateEntries(List<CrashLogEntry> entries) {
  if (entries.length <= CrashLogRepositoryLimits.maxEntries) return entries;
  return entries.sublist(entries.length - CrashLogRepositoryLimits.maxEntries);
}

/// ローテーション上限の置き場（実装間で共有）。
class CrashLogRepositoryLimits {
  /// 保持する最大件数。
  static const int maxEntries = 50;
}

/// 端末内ファイル（documents/crash_log.jsonl）に追記する実装。
///
/// - 1行1 JSON。壊れた行は読み飛ばす（ログのために落ちない）。
/// - 直近 [CrashLogRepositoryLimits.maxEntries] 件でローテート。
/// - 入出力の失敗は握りつぶす（クラッシュ記録でクラッシュしない）。
class FileCrashLogRepository implements CrashLogRepository {
  /// ファイル名。
  static const String fileName = 'crash_log.jsonl';

  /// 保存先ディレクトリの解決方法（試練で差し替える）。
  final Future<Directory> Function() directoryProvider;

  FileCrashLogRepository({Future<Directory> Function()? directoryProvider})
      : directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  Future<File> _resolveFile() async {
    final dir = await directoryProvider();
    return File('${dir.path}/$fileName');
  }

  @override
  Future<List<CrashLogEntry>> loadAll() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return const <CrashLogEntry>[];
      final raw = await file.readAsString();
      final entries = <CrashLogEntry>[];
      for (final line in const LineSplitter().convert(raw)) {
        if (line.trim().isEmpty) continue;
        final entry = _decodeLine(line);
        if (entry != null) entries.add(entry);
      }
      return entries;
    } catch (_) {
      return const <CrashLogEntry>[];
    }
  }

  CrashLogEntry? _decodeLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) return null;
      return CrashLogEntry.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> append(CrashLogEntry entry) async {
    try {
      final existing = await loadAll();
      final next = rotateEntries(<CrashLogEntry>[...existing, entry]);
      final buffer = StringBuffer();
      for (final item in next) {
        buffer.writeln(jsonEncode(item.toJson()));
      }
      final file = await _resolveFile();
      await file.writeAsString(buffer.toString(), flush: true);
    } catch (_) {
      // 記録できなくてもアプリは動かす。
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 消せなくても致命的ではない。
    }
  }
}

/// 試練用のメモリ内実装（同じローテーション規約に従う）。
class InMemoryCrashLogRepository implements CrashLogRepository {
  final List<CrashLogEntry> _entries = <CrashLogEntry>[];

  /// 現在の件数（試練の補助）。
  int get length => _entries.length;

  @override
  Future<List<CrashLogEntry>> loadAll() async =>
      List<CrashLogEntry>.unmodifiable(_entries);

  @override
  Future<void> append(CrashLogEntry entry) async {
    _entries.add(entry);
    final rotated = rotateEntries(_entries);
    if (rotated.length != _entries.length) {
      _entries
        ..clear()
        ..addAll(rotated);
    }
  }

  @override
  Future<void> clear() async => _entries.clear();
}
