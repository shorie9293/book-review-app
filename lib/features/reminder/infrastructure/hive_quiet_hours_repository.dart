import 'dart:convert';

import 'package:book_review_app/features/reminder/data/quiet_hours_repository.dart';
import 'package:book_review_app/features/reminder/domain/quiet_hours_settings.dart';
import 'package:hive/hive.dart';

/// Hive 実装。box `quiet_hours_box` / key `quiet_hours_settings` に
/// JSON 文字列で保存する。
///
/// [Hive.init] は呼ばない（呼び出し側が初期化済みである前提）。
/// 未初期化・open 失敗・破損レコードは [QuietHoursSettings.defaults] へ
/// フォールバックする（通知経路が例外やハングで止まらない）。
class HiveQuietHoursRepository implements QuietHoursRepository {
  HiveQuietHoursRepository({Box<String>? box, this.openIfMissing = true})
      : _injected = box;

  static const String boxName = 'quiet_hours_box';
  static const String keyName = 'quiet_hours_settings';

  final Box<String>? _injected;

  /// false なら「既に open 済みの box を読むだけ」にし、無ければ
  /// 既定値を返す。通知経路の既定ガードはこれを false で使う。
  final bool openIfMissing;

  Box<String>? _opened;

  Future<Box<String>?> _box() async {
    if (_injected != null) return _injected;
    if (_opened != null && _opened!.isOpen) return _opened;
    try {
      if (Hive.isBoxOpen(boxName)) {
        _opened = Hive.box<String>(boxName);
        return _opened;
      }
      if (!openIfMissing) return null;
      _opened = await Hive.openBox<String>(boxName);
      return _opened;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<QuietHoursSettings> load() async {
    try {
      final box = await _box();
      if (box == null) return QuietHoursSettings.defaults();
      final raw = box.get(keyName);
      if (raw is! String) return QuietHoursSettings.defaults();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return QuietHoursSettings.defaults();
      }
      return QuietHoursSettings.fromJson(decoded);
    } catch (_) {
      return QuietHoursSettings.defaults();
    }
  }

  @override
  Future<void> save(QuietHoursSettings settings) async {
    final box = await _box();
    if (box == null) return;
    try {
      await box.put(keyName, jsonEncode(settings.toJson()));
    } catch (_) {
      // 保存失敗は握り潰す（設定画面を壊さない）。
    }
  }
}
