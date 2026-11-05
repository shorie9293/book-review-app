import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:book_review_app/features/auto_backup/domain/auto_backup_status.dart';

/// 自動バックアップの状態（最終成功・最終試行・連続失敗）の保管先。
abstract class AutoBackupStatusStore {
  /// 保存済みの状態を読み出す（無ければ null）。
  Future<AutoBackupStatus?> load();

  /// 状態を保存する（同名は上書き）。
  Future<void> save(AutoBackupStatus status);
}

/// 試練・プレビュー用のインメモリ保管先。
class InMemoryAutoBackupStatusStore implements AutoBackupStatusStore {
  AutoBackupStatus? _status;

  /// 初期状態を仕込める（試練用）。
  InMemoryAutoBackupStatusStore([this._status]);

  @override
  Future<AutoBackupStatus?> load() async => _status;

  @override
  Future<void> save(AutoBackupStatus status) async {
    _status = status;
  }
}

/// 端末の documents/auto_backups 配下へ状態を1ファイルで保存する。
///
/// ファイル名は自動バックアップの命名規約（`auto_backup_yyyyMMdd.json`）に
/// 一致しないため、一覧・世代整理には現れない。
class FileAutoBackupStatusStore implements AutoBackupStatusStore {
  /// 状態ファイル名。
  static const String fileName = 'auto_backup_status.json';

  /// 保存先ディレクトリ名（[FileAutoBackupStore] と同一）。
  static const String directoryName = 'auto_backups';

  final Future<Directory> Function() _resolveDirectory;

  /// [directoryResolver] を注入できる（試練では一時ディレクトリを渡す）。
  FileAutoBackupStatusStore({Future<Directory> Function()? directoryResolver})
      : _resolveDirectory = directoryResolver ?? _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}$directoryName');
  }

  Future<File> _file() async {
    final dir = await _resolveDirectory();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<AutoBackupStatus?> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return AutoBackupStatus.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AutoBackupStatus status) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(status.toJson()), flush: true);
  }
}
