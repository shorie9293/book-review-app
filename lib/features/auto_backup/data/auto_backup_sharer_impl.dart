import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:book_review_app/features/auto_backup/domain/auto_backup_sharer.dart';

/// [AutoBackupSharer] の share_plus 実装。
///
/// 内容を一時ファイルへ書き出してから共有する
/// （アプリ専用領域のファイルは他アプリから読めないため）。
class SharePlusAutoBackupSharer implements AutoBackupSharer {
  final Future<Directory> Function() _resolveDirectory;
  final Future<void> Function(XFile file, String text) _send;

  /// [directoryResolver] と [send] を注入できる（試練用）。
  SharePlusAutoBackupSharer({
    Future<Directory> Function()? directoryResolver,
    Future<void> Function(XFile file, String text)? send,
  })  : _resolveDirectory = directoryResolver ?? getTemporaryDirectory,
        _send = send ?? _shareWithPlus;

  static Future<void> _shareWithPlus(XFile file, String text) async {
    await SharePlus.instance.share(
      ShareParams(files: [file], text: text),
    );
  }

  @override
  Future<void> share(String fileName, String json) async {
    final dir = await _resolveDirectory();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(json, flush: true);
    await _send(
      XFile(file.path, mimeType: 'application/json', name: fileName),
      'バックアップ $fileName',
    );
  }
}
