import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

  /// 復帰時に再施錠するまでの猶予秒数（既定 0 = 即時）。
  int getRelockGraceSeconds();

  /// 復帰時猶予秒数を保存する。
  Future<void> setRelockGraceSeconds(int seconds);

  /// 連続失敗回数。
  int getFailedAttempts();

  /// 失敗回数を保存する。
  Future<void> setFailedAttempts(int attempts);

  /// ロックアウト解除時刻（未ロックアウトは null）。
  DateTime? getLockedUntil();

  /// ロックアウト解除時刻を保存する（null でクリア）。
  Future<void> setLockedUntil(DateTime? until);

  /// 失敗回数とロックアウトを初期化する。
  Future<void> resetAttempts();
}

/// 旧形式ハッシュの固定ソルト。
const String kAppLockSalt = 'book-app-lock:';

/// v2 ハッシュの反復回数。
const int kAppLockHashIterations = 1200;

/// v2 ハッシュのソルト長（バイト）。
const int kAppLockSaltBytes = 16;

/// 旧形式（端末共通ソルト・単発 sha256）のハッシュ。
String hashPasscode(String passcode) {
  final bytes = utf8.encode(kAppLockSalt + passcode);
  return sha256.convert(bytes).toString();
}

/// 端末ごとのランダムソルト（16バイト hex）。
String newPasscodeSaltHex() {
  final random = Random.secure();
  final bytes = List<int>.generate(kAppLockSaltBytes, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// ソルト付き反復ハッシュのダイジェスト（hex）。
String derivePasscodeHash(
  String passcode,
  String saltHex, {
  int iterations = kAppLockHashIterations,
}) {
  var digest = sha256.convert(utf8.encode('$saltHex:$passcode'));
  for (var i = 1; i < iterations; i++) {
    digest = sha256.convert(digest.bytes);
  }
  return digest.toString();
}

/// v2 形式 `v2:<iterations>:<saltHex>:<hashHex>` を生成する。
String encodePasscodeHash(
  String passcode, {
  String? saltHex,
  int iterations = kAppLockHashIterations,
}) {
  final salt = saltHex ?? newPasscodeSaltHex();
  final digest = derivePasscodeHash(passcode, salt, iterations: iterations);
  return 'v2:$iterations:$salt:$digest';
}

/// 保存済みハッシュとパスコードの照合（v2 / 旧形式の両対応）。
bool matchesPasscodeHash(String stored, String passcode) {
  if (stored.startsWith('v2:')) {
    final parts = stored.split(':');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    final digest = derivePasscodeHash(
      passcode,
      parts[2],
      iterations: iterations,
    );
    return constantTimeEquals(parts[3], digest);
  }
  return constantTimeEquals(stored, hashPasscode(passcode));
}

/// 保存済みハッシュが旧形式（移行対象）か。
bool isLegacyPasscodeHash(String stored) => !stored.startsWith('v2:');

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
  static const String _kGrace = 'app_lock.relock_grace_seconds';
  static const String _kFailedAttempts = 'app_lock.failed_attempts';
  static const String _kLockedUntil = 'app_lock.locked_until_epoch_ms';

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
    await box.put(_kHash, encodePasscodeHash(passcode));
    await resetAttempts();
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
    final ok = matchesPasscodeHash(stored, passcode);
    if (ok && isLegacyPasscodeHash(stored)) {
      unawaited(_migrateToV2(passcode));
    }
    return ok;
  }

  /// 旧形式からの無強制移行（投げっぱなし・失敗は無視）。
  Future<void> _migrateToV2(String passcode) async {
    try {
      await setPasscode(passcode);
    } catch (_) {
      // 移行失敗は旧形式のまま照合を継続する。
    }
  }

  @override
  int getRelockGraceSeconds() {
    final value = _read(_kGrace);
    if (value is int) return value < 0 ? 0 : value;
    return 0;
  }

  @override
  Future<void> setRelockGraceSeconds(int seconds) async {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', '0以上を指定せよ');
    }
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_kGrace, seconds);
  }

  @override
  int getFailedAttempts() {
    final value = _read(_kFailedAttempts);
    if (value is int) return value < 0 ? 0 : value;
    return 0;
  }

  @override
  Future<void> setFailedAttempts(int attempts) async {
    if (attempts < 0) {
      throw ArgumentError.value(attempts, 'attempts', '0以上を指定せよ');
    }
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_kFailedAttempts, attempts);
  }

  @override
  DateTime? getLockedUntil() {
    final value = _read(_kLockedUntil);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  @override
  Future<void> setLockedUntil(DateTime? until) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    if (until == null) {
      await box.delete(_kLockedUntil);
      return;
    }
    await box.put(_kLockedUntil, until.millisecondsSinceEpoch);
  }

  @override
  Future<void> resetAttempts() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<dynamic>(_boxName);
    await box.put(_kFailedAttempts, 0);
    await box.delete(_kLockedUntil);
  }
}

/// 試練用インメモリ実装。
class InMemoryAppLockRepository implements AppLockRepository {
  bool _enabled = false;
  AppLockMethod _method = AppLockMethod.none;
  String? _hash;
  int _graceSeconds = 0;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

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
  Future<void> setPasscode(String passcode) async {
    _hash = encodePasscodeHash(passcode);
    await resetAttempts();
  }

  @override
  Future<void> clearPasscode() async => _hash = null;

  @override
  bool verifyPasscode(String passcode) {
    final stored = _hash;
    if (stored == null) return false;
    final ok = matchesPasscodeHash(stored, passcode);
    if (ok && isLegacyPasscodeHash(stored)) {
      unawaited(_migrateToV2(passcode));
    }
    return ok;
  }

  Future<void> _migrateToV2(String passcode) async {
    _hash = encodePasscodeHash(passcode);
  }

  @override
  int getRelockGraceSeconds() => _graceSeconds;

  @override
  Future<void> setRelockGraceSeconds(int seconds) async {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', '0以上を指定せよ');
    }
    _graceSeconds = seconds;
  }

  @override
  int getFailedAttempts() => _failedAttempts;

  @override
  Future<void> setFailedAttempts(int attempts) async {
    if (attempts < 0) {
      throw ArgumentError.value(attempts, 'attempts', '0以上を指定せよ');
    }
    _failedAttempts = attempts;
  }

  @override
  DateTime? getLockedUntil() => _lockedUntil;

  @override
  Future<void> setLockedUntil(DateTime? until) async => _lockedUntil = until;

  @override
  Future<void> resetAttempts() async {
    _failedAttempts = 0;
    _lockedUntil = null;
  }
}
