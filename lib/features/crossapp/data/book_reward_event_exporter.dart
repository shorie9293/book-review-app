import 'dart:convert';
import 'dart:io';

import 'package:book_review_app/core/infrastructure/shared_file_store.dart';
import 'package:book_review_app/core/logging/app_logger.dart';

/// 読了報酬イベントを共有ストレージへ JSONL として1行追記する。
///
/// 5 現世（rpg-task / tsundoku-quest / kozuchi / election-game / book-review-app）は
/// **ユーザーが SAF（Storage Access Framework）で選んだ共有フォルダ**を介して
/// ファイルを受け渡す。サンドボックス外の固定パス（端末の一時領域など）へ
/// アプリから直接書くことは Android 10+ の scoped storage ではできない（DAC で EACCES）。
/// したがって書き出し先は [SharedFileStore] が解決する。
///
/// - 既定（[filePath] が null）: [SharedFileStore.instance] へ
///   `book_review_reward_events.jsonl` を追記する。実機では SAF の共有フォルダ。
/// - [filePath] 明示時: そのパスへ直接追記する（試練・デスクトップ用の後方互換）。
///
/// 共有ストア経由の失敗は**握りつぶさず** [SharedStorageException] として上位へ返す。
/// 呼び出し側（読了処理）はこれを「連携失敗」として warn に残し、読了そのものは止めない。
class BookRewardEventExporter {
  const BookRewardEventExporter({
    this.filePath,
    this.lineWriter,
    this.store,
    this.logger,
  });

  /// 共有フォルダ直下のファイル名。5 現世の契約名は
  /// [SharedCrossAppFiles.bookReviewRewardEvents] が正本。
  static const String fileName = SharedCrossAppFiles.bookReviewRewardEvents;

  /// 書き出し先の明示パス。null（既定）なら共有ストア経由。
  final String? filePath;

  /// 試練注入用の行書き込みフック。
  ///
  /// 受け取る [line] は改行を含まない JSON 文字列。null なら実ファイル /
  /// 共有ストアへ追記する。
  final Future<void> Function(String path, String line)? lineWriter;

  /// 共有ストア（試練でフェイクを注入する）。null なら [SharedFileStore.instance]。
  final ISharedFileStore? store;

  /// ログ（試練で捕捉する）。null ならアプリ共通の [appLog]。
  final AppLogger? logger;

  /// JSONL 1行を追記する。
  ///
  /// - 共有ストア経由（既定）の成功で true。失敗は [SharedStorageException] を投げる。
  /// - 明示パス / 注入ライタ経由は従来契約を保ち、失敗時は warn を1行残して false。
  Future<bool> append(Map<String, dynamic> event) async {
    final line = jsonEncode(event);

    final path = filePath;
    if (path != null) {
      return _bestEffort('明示パス', () async {
        final writer = lineWriter;
        if (writer != null) {
          await writer(path, line);
          return;
        }
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      });
    }

    final writer = lineWriter;
    if (writer != null) {
      return _bestEffort('注入ライタ', () => writer(fileName, line));
    }

    // 本番経路: 共有ストア（Android 実機では SAF）。失敗は無音にしない。
    await (store ?? SharedFileStore.instance).appendLine(fileName, line);
    return true;
  }

  /// 後方互換経路のベストエフォート実行。例外は投げず、warn を1行残す。
  Future<bool> _bestEffort(String route, Future<void> Function() body) async {
    try {
      await body();
      return true;
    } catch (e) {
      (logger ?? appLog).warn('[BookRewardEventExporter] 追記失敗（$route）', e);
      return false;
    }
  }
}
