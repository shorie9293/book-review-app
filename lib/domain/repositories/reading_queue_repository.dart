import 'package:book_review_app/domain/models/reading_queue_entry.dart';

/// 「次に読む」キューの永続化抽象。
abstract interface class ReadingQueueRepository {
  /// キューの全エントリを返す（順序は保存順を問わない）。
  Future<List<ReadingQueueEntry>> loadEntries();

  /// キュー全体を上書き保存する。
  Future<void> saveEntries(List<ReadingQueueEntry> entries);
}
