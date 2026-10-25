import 'dart:convert';
import 'dart:io';

/// 報酬イベントを共有ストレージへ JSONL として1行追記する。
///
/// rpg-task の `FileCrossAppRewardService` が走査するパスと一致させる
/// （参照: rpg-task/lib/features/crossapp/data/cross_app_reward_service.dart の
/// `kDefaultBookReviewEventsPath`）。Android では `/data/local/tmp` 配下が
/// アプリ間で共有される。
class BookRewardEventExporter {
  const BookRewardEventExporter({
    this.filePath = kDefaultBookReviewEventsPath,
    this.lineWriter,
  });

  /// rpg-task 契約 v1 の既定パス。
  static const String kDefaultBookReviewEventsPath =
      '/data/local/tmp/takamagahara_shared/book_review_reward_events.jsonl';

  /// 書き出し先ファイルパス。
  final String filePath;

  /// 試練注入用の行書き込みフック。
  ///
  /// 受け取る [line] は改行を含まない JSON 文字列。null なら実ファイルへ追記する。
  final Future<void> Function(String path, String line)? lineWriter;

  /// 親ディレクトリを作成して JSONL 1行を追記する。
  ///
  /// 成功で true、失敗は握りつぶして false。例外は投げない（best-effort）。
  Future<bool> append(Map<String, dynamic> event) async {
    try {
      final line = jsonEncode(event);
      final writer = lineWriter;
      if (writer != null) {
        await writer(filePath, line);
        return true;
      }
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      return true;
    } catch (_) {
      // best-effort: 書き出せなくてもアプリを落とさない
      return false;
    }
  }
}
