import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/domain/repositories/reading_queue_repository.dart';
import 'package:book_review_app/features/queue/domain/reading_queue_service.dart';

/// Hive を使用した [ReadingQueueRepository] の実装。
///
/// エントリは JSON 文字列として保存する（TypeAdapter 不要）。
/// 破損エントリは読み飛ばし、他のエントリの読み取りを妨げない。
class HiveReadingQueueRepository implements ReadingQueueRepository {
  late Box<String> _box;

  /// Hive のボックス名
  static const String defaultBoxName = 'reading_queue';

  /// 初期化（テスト時は boxName を指定して呼び出す）
  Future<void> init({String? boxName}) async {
    _box = await Hive.openBox<String>(boxName ?? defaultBoxName);
  }

  /// テスト用：ボックスをクリアする
  Future<void> clear() async {
    await _box.clear();
  }

  /// ボックスを閉じる
  Future<void> close() async {
    await _box.close();
  }

  /// 破損エントリを読み飛ばして全件復元する
  List<ReadingQueueEntry> _readAll() {
    final entries = <ReadingQueueEntry>[];
    for (final raw in _box.values) {
      final entry = _decode(raw);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  ReadingQueueEntry? _decode(String raw) {
    try {
      final map = json.decode(raw);
      if (map is! Map<String, dynamic>) return null;
      return ReadingQueueEntry.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ReadingQueueEntry>> loadEntries() async {
    return ReadingQueueService.normalize(_readAll());
  }

  @override
  Future<void> saveEntries(List<ReadingQueueEntry> entries) async {
    await _box.clear();
    for (final entry in ReadingQueueService.normalize(entries)) {
      await _box.put(entry.bookId, json.encode(entry.toJson()));
    }
  }
}

/// テスト・プレビュー用のインメモリ実装。
class InMemoryReadingQueueRepository implements ReadingQueueRepository {
  final Map<String, ReadingQueueEntry> _store = {};

  /// 現在保持しているエントリ件数
  int get length => _store.length;

  @override
  Future<List<ReadingQueueEntry>> loadEntries() async {
    return ReadingQueueService.normalize(_store.values.toList());
  }

  @override
  Future<void> saveEntries(List<ReadingQueueEntry> entries) async {
    final normalized = ReadingQueueService.normalize(entries);
    _store
      ..clear()
      ..addEntries([for (final e in normalized) MapEntry(e.bookId, e)]);
  }
}

/// 何もしない実装（プレビュー・フォールバック用）。
class NoopReadingQueueRepository implements ReadingQueueRepository {
  @override
  Future<List<ReadingQueueEntry>> loadEntries() async => const [];

  @override
  Future<void> saveEntries(List<ReadingQueueEntry> entries) async {}
}
