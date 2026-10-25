import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';

/// 読了イベント（`book_completed`）の判定・生成を担う純粋ドメインサービス。
///
/// 出力契約は rpg-task の `CrossAppRewardEvent` に合わせる:
/// 必須キーは event_id / event_type / user_id / timestamp、
/// 報酬計算は `metadata['count']` を `as int?` で読むため **int** でなければならない。
class BookRewardEventService {
  const BookRewardEventService();

  /// 読了イベントのイベントタイプ。
  static const String eventType = 'book_completed';

  /// [previous] が読了でなく [updated] が読了のときのみ true。
  ///
  /// 読了→読了や読了→読書中は書き出さない（再送・巻き戻しを防ぐ）。
  bool shouldExport({required Book previous, required Book updated}) {
    return !_isFinished(previous) && _isFinished(updated);
  }

  /// 読了冊数（`readingStatus == ReadingStatus.finished` の件数）。
  int completedCountOf(Iterable<Book> books) {
    var count = 0;
    for (final book in books) {
      if (_isFinished(book)) count++;
    }
    return count;
  }

  /// JSONL 1行分の Map を生成する。
  ///
  /// [userId] が空/空白のみ、または [completedCount] が負なら [ArgumentError]。
  /// 不正なイベントを書き出すと rpg-task 側で行ごと破棄されるため、
  /// 生成時点で失敗させる（呼び出し側の coordinator が握りつぶす）。
  Map<String, dynamic> buildCompletionEvent({
    required String userId,
    required Book book,
    required int completedCount,
    required String eventId,
    required DateTime timestamp,
  }) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'userId は必須です');
    }
    if (completedCount < 0) {
      throw ArgumentError.value(
        completedCount,
        'completedCount',
        'completedCount は 0 以上である必要があります',
      );
    }

    return <String, dynamic>{
      'event_id': eventId,
      'event_type': eventType,
      'user_id': userId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'metadata': <String, dynamic>{
        // rpg 側は `metadata['count'] as int?` で読む（double は行ごと破棄）
        'count': completedCount,
        'book_id': book.id,
        'book_title': book.title,
      },
    };
  }

  /// 冪等キー: `'<book.id>|<finishedAt?.toIso8601String() ?? "">'`。
  ///
  /// 同じ本を読み直して再度読了しても、finishedAt が変われば別イベントとして扱う。
  String sentKeyOf(Book book) {
    return '${book.id}|${book.finishedAt?.toIso8601String() ?? ''}';
  }

  bool _isFinished(Book book) => book.readingStatus == ReadingStatus.finished;
}
