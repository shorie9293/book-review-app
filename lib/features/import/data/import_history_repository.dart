import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:book_review_app/features/import/domain/import_history_entry.dart';

/// 取込履歴の永続化契約。
abstract class ImportHistoryRepository {
  /// 保存済みの履歴を新しい順で読み出す。
  Future<List<ImportHistoryEntry>> load();

  /// 履歴を丸ごと保存する（全置換）。
  Future<void> save(List<ImportHistoryEntry> entries);
}

/// テスト・プレビュー用のメモリ実装。
class InMemoryImportHistoryRepository implements ImportHistoryRepository {
  List<ImportHistoryEntry> _entries;

  InMemoryImportHistoryRepository([List<ImportHistoryEntry> initial = const []])
      : _entries = List<ImportHistoryEntry>.from(initial);

  @override
  Future<List<ImportHistoryEntry>> load() async =>
      List<ImportHistoryEntry>.from(_entries);

  @override
  Future<void> save(List<ImportHistoryEntry> entries) async {
    _entries = List<ImportHistoryEntry>.from(entries);
  }
}

/// Hive による履歴の永続化。
///
/// 1件1キー（`records.<index>`）に JSON 文字列として保存する。
/// 要素単位で復元するため、破損した1件があっても他は読み出せる。
class HiveImportHistoryRepository implements ImportHistoryRepository {
  /// 既定の箱名
  static const String boxName = 'import_history_box';

  /// 保存キーの接頭辞
  static const String storageKey = 'records';

  String? _openedBoxName;

  /// 実際に開いた（開こうとした）箱名。
  String get openedBoxName => _openedBoxName ?? boxName;

  /// 箱を開く。失敗しても例外を投げない（best-effort）。
  Future<void> init({String? boxNameOverride}) async {
    final name = boxNameOverride ?? boxName;
    _openedBoxName = name;
    // パス区切り等を含む名前は Hive が非同期の未処理例外を投げるため、事前に弾く
    if (!_isUsableBoxName(name)) return;
    try {
      if (Hive.isBoxOpen(name)) return;
      await Hive.openBox<String>(name);
    } catch (_) {
      // 開けなくても load は空リストを返すだけなので握りつぶす
    }
  }

  bool _isUsableBoxName(String name) {
    if (name.trim().isEmpty) return false;
    if (name.contains('/') || name.contains('\\')) return false;
    if (name.contains('..')) return false;
    return true;
  }

  String _keyAt(int index) => '$storageKey.$index';

  int _indexOfKey(Object? key) {
    if (key is! String) return -1;
    final prefix = '$storageKey.';
    if (!key.startsWith(prefix)) return -1;
    return int.tryParse(key.substring(prefix.length)) ?? -1;
  }

  @override
  Future<List<ImportHistoryEntry>> load() async {
    final name = openedBoxName;
    try {
      if (!Hive.isBoxOpen(name)) return <ImportHistoryEntry>[];
      final box = Hive.box<String>(name);

      final keys = box.keys.where((k) => _indexOfKey(k) >= 0).toList()
        ..sort((a, b) => _indexOfKey(a).compareTo(_indexOfKey(b)));

      final entries = <ImportHistoryEntry>[];
      for (final key in keys) {
        // 要素単位で守る: 破損要素は読み飛ばす
        try {
          final raw = box.get(key);
          if (raw is! String) continue;
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          entries.add(
            ImportHistoryEntry.fromJson(Map<String, dynamic>.from(decoded)),
          );
        } catch (_) {
          continue;
        }
      }
      return entries;
    } catch (_) {
      return <ImportHistoryEntry>[];
    }
  }

  @override
  Future<void> save(List<ImportHistoryEntry> entries) async {
    final name = openedBoxName;
    try {
      if (!Hive.isBoxOpen(name)) return;
      final box = Hive.box<String>(name);
      await box.clear();
      for (var i = 0; i < entries.length; i++) {
        await box.put(_keyAt(i), jsonEncode(entries[i].toJson()));
      }
    } catch (_) {
      // best-effort: 保存失敗でもアプリを落とさない
    }
  }
}
