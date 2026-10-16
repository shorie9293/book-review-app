import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

/// ロック方式。
enum AppLockMethod { none, passcode, biometric }

/// アプリロック設定の永続化の抽象（本現世は Hive・SharedPreferences に依存しない）。
abstract class AppLockRepository {
  /// ロックが有効か。
  bool isEnabled();

  /// ロックの有効/無効を保存する。
  Future<void> setEnabled(bool enabled);

  /// 現在のロック方式。
  AppLockMethod getMethod();

  /// ロック方式を保存する。
  Future<void> setMethod(AppLockMethod method);

  /// 保存済みパスコードハッシュ（未設定は null）。
  String? getPasscodeHash();

  /// パスコードをハッシュ化して保存する。
  Future<void> setPasscode(String passcode);

  /// パスコードを消去する。
  Future<void> clearPasscode();

  /// パスコード照合（定数時間比較）。
  bool verifyPasscode(String passcode);
}

/// パスコードのソルト。
const String kAppLockSalt = 'book-app-lock:';

/// パスコードを sha256 でハッシュ化する。
String hashPasscode(String passcode) {
  final bytes = utf8.encode(kAppLockSalt + passcode);
  return sha256.convert(bytes).toString();
}

/// 定数時間比較（長さ不一致は早期返却するがハッシュ長は常に一定）。
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Hive 実装。テーマ設定と同じ settings ボックスを使う。
class HiveAppLockRepository implements AppLockRepository {
  static const String _boxName = 'settings';
  static const String _kEnabled = 'app_lock.enabled';
  static const String _kMethod = 'app_lock.method';
  static const String _kHash = 'app_lock.passcode_hash';

  const HiveAppLockRepository();

  /// ボックスが開いていれば同期的に読める。未初期化環境では fail-open。
  dynamic _read(String key) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    try {
      return Hive.box<dynamic>(_boxName).get(key);
    } catch (_) {
      return null;
    }
  }

  @override
  bool isEnabled() => _read(_kEnabled) == true;

  @override
  Future<void> setEnabled(bool enabled) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_kEnabled, enabled);
  }

  @override
  AppLockMethod getMethod() {
    final name = _read(_kMethod);
    if (name is! String) return AppLockMethod.none;
    for (final m in AppLockMethod.values) {
      if (m.name == name) return m;
    }
    return AppLockMethod.none;
  }

  @override
  Future<void> setMethod(AppLockMethod method) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_kMethod, method.name);
  }

  @override
  String? getPasscodeHash() {
    final hash = _read(_kHash);
    return hash is String ? hash : null;
  }

  @override
  Future<void> setPasscode(String passcode) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_kHash, hashPasscode(passcode));
  }

  @override
  Future<void> clearPasscode() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    await Hive.box<dynamic>(_boxName).delete(_kHash);
  }

  @override
  bool verifyPasscode(String passcode) {
    final stored = getPasscodeHash();
    if (stored == null) return false;
    return constantTimeEquals(stored, hashPasscode(passcode));
  }
}

/// 試練用インメモリ実装。
class InMemoryAppLockRepository implements AppLockRepository {
  bool _enabled = false;
  AppLockMethod _method = AppLockMethod.none;
  String? _hash;

  @override
  bool isEnabled() => _enabled;

  @override
  Future<void> setEnabled(bool enabled) async => _enabled = enabled;

  @override
  AppLockMethod getMethod() => _method;

  @override
  Future<void> setMethod(AppLockMethod method) async => _method = method;

  @override
  String? getPasscodeHash() => _hash;

  @override
  Future<void> setPasscode(String passcode) async =>
      _hash = hashPasscode(passcode);

  @override
  Future<void> clearPasscode() async => _hash = null;

  @override
  bool verifyPasscode(String passcode) {
    final stored = _hash;
    if (stored == null) return false;
    return constantTimeEquals(stored, hashPasscode(passcode));
  }
}
