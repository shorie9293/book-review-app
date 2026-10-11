/// シェアカードの共有（書き出し）抽象と share_plus 実装。
library;

import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// 共有処理の抽象（テストでフェイク注入可能にする）。
abstract class ShareCardExporter {
  /// [image] が非nullならファイル添付付き、nullならテキストのみで共有する。
  /// 成功したら true を返す。
  Future<bool> share({Uint8List? image, required String text});
}

/// share_plus 実装のエクスポーター。
class SharePlusExporter implements ShareCardExporter {
  const SharePlusExporter();

  @override
  Future<bool> share({Uint8List? image, required String text}) async {
    final params = image != null
        ? ShareParams(
            files: [
              XFile.fromData(
                image,
                name: 'share_card.png',
                mimeType: 'image/png',
              ),
            ],
            text: text,
          )
        : ShareParams(text: text);
    final result = await SharePlus.instance.share(params);
    return result.status == ShareResultStatus.success;
  }
}
