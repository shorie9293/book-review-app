import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';

/// 自動バックアップの保管先インターフェース。
abstract class AutoBackupStore {
  /// 自動バックアップの一覧（自動ファイルのみ・順序は保証しない）。
  Future<List<AutoBackupEntry>> list();

  /// 1世代を書き出す（同名は上書き）。
  Future<void> write(String fileName, String json);

  /// 1世代を読み出す（無ければ null）。
  Future<String?> read(String fileName);

  /// 1世代を削除する（無ければ何もしない）。
  Future<void> delete(String fileName);
}

/// 試練・プレビュー用のインメモリ保管先。
class InMemoryAutoBackupStore implements AutoBackupStore {
  final Map<String, String> _files = <String, String>{};
  final Map<String, DateTime> _createdAt = <String, DateTime>{};
  final DateTime Function() _now;

  /// [now] を注入できる（既定は [DateTime.now]）。
  InMemoryAutoBackupStore({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// 既存世代を直接仕込む（試練用）。
  void seed({
    required String fileName,
    required DateTime createdAt,
    String contents = '{}',
  }) {
    _files[fileName] = contents;
    _createdAt[fileName] = createdAt;
  }

  @override
  Future<List<AutoBackupEntry>> list() async {
    return [
      for (final entry in _files.entries)
        if (AutoBackupPolicy.isAutoBackupFile(entry.key))
          AutoBackupEntry(
            fileName: entry.key,
            createdAt: _createdAt[entry.key] ?? _now(),
          ),
    ];
  }

  @override
  Future<void> write(String fileName, String json) async {
    _files[fileName] = json;
    _createdAt.putIfAbsent(fileName, _now);
  }

  @override
  Future<String?> read(String fileName) async => _files[fileName];

  @override
  Future<void> delete(String fileName) async {
    _files.remove(fileName);
    _createdAt.remove(fileName);
  }
}

/// 端末の documents/auto_backups 配下へ書き出す保管先。
class FileAutoBackupStore implements AutoBackupStore {
  /// 保存先ディレクトリ名。
  static const String directoryName = 'auto_backups';

  final Future<Directory> Function() _resolveDirectory;

  /// [directoryResolver] を注入できる（試練では一時ディレクトリを渡す）。
  FileAutoBackupStore({Future<Directory> Function()? directoryResolver})
      : _resolveDirectory = directoryResolver ?? _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}$directoryName');
  }

  Future<Directory> _ensureDirectory() async {
    final dir = await _resolveDirectory();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File _fileIn(Directory dir, String fileName) =>
      File('${dir.path}${Platform.pathSeparator}$fileName');

  @override
  Future<List<AutoBackupEntry>> list() async {
    final dir = await _ensureDirectory();
    if (!dir.existsSync()) return const [];
    final entries = <AutoBackupEntry>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final fileName = entity.uri.pathSegments.last;
      if (!AutoBackupPolicy.isAutoBackupFile(fileName)) continue;
      // createdAt 不明時はファイル更新時刻で補う。
      final stat = await entity.stat();
      entries.add(
        AutoBackupEntry(fileName: fileName, createdAt: stat.modified),
      );
    }
    return entries;
  }

  @override
  Future<void> write(String fileName, String json) async {
    final dir = await _ensureDirectory();
    await _fileIn(dir, fileName).writeAsString(json, flush: true);
  }

  @override
  Future<String?> read(String fileName) async {
    final dir = await _ensureDirectory();
    final file = _fileIn(dir, fileName);
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  @override
  Future<void> delete(String fileName) async {
    final dir = await _ensureDirectory();
    final file = _fileIn(dir, fileName);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
