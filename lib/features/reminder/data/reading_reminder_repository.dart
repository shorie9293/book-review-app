import 'dart:convert';

import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:hive/hive.dart';

/// 読書リマインダー設定の永続化インターフェース。
abstract class ReadingReminderRepository {
  Future<ReadingReminderSettings> load();
  Future<void> save(ReadingReminderSettings s);
}

/// Hive 実装。box `reading_reminder_box` / key `readingReminder` に
/// JSON 文字列で保存。破損・型不一致レコードは
/// [ReadingReminderSettings.defaults] へフォールバックする。
class HiveReadingReminderRepository implements ReadingReminderRepository {
  static const String boxName = 'reading_reminder_box';
  static const String keyName = 'readingReminder';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  @override
  Future<ReadingReminderSettings> load() async {
    final box = await _getBox();
    final raw = box.get(keyName);
    if (raw is! String) return ReadingReminderSettings.defaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return ReadingReminderSettings.defaults();
      }
      return ReadingReminderSettings.fromJson(decoded);
    } catch (_) {
      return ReadingReminderSettings.defaults();
    }
  }

  @override
  Future<void> save(ReadingReminderSettings s) async {
    final box = await _getBox();
    await box.put(keyName, jsonEncode(s.toJson()));
  }
}

/// 試練用のメモリ内リポジトリ。初期値を注入できる。
class InMemoryReadingReminderRepository implements ReadingReminderRepository {
  InMemoryReadingReminderRepository([ReadingReminderSettings? initial])
      : _settings = initial ?? ReadingReminderSettings.defaults();

  ReadingReminderSettings _settings;

  @override
  Future<ReadingReminderSettings> load() async => _settings;

  @override
  Future<void> save(ReadingReminderSettings s) async => _settings = s;
}
