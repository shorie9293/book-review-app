import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'package:book_review_app/features/backup/domain/csv_bytes.dart';

/// 蔵書 CSV の共有抽象（試練ではフェイクを注入する）。
///
/// 渡される [csv] は BOM 無しの素の CSV。BOM 付与は実装側の責務。
abstract interface class BackupCsvSharer {
  Future<void> share({required String csv, required String fileName});
}

/// ローカル暦の `book_backup_yyyyMMdd.csv` を組み立てる。
String backupCsvFileName(DateTime now) {
  final local = now.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return 'book_backup_$year$month$day.csv';
}

/// share_plus 実装。CSV を BOM 付き UTF-8 のファイルとして共有シートへ渡す。
class SharePlusBackupCsvSharer implements BackupCsvSharer {
  const SharePlusBackupCsvSharer();

  @override
  Future<void> share({required String csv, required String fileName}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(csvBytes(csv)),
            name: fileName,
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
