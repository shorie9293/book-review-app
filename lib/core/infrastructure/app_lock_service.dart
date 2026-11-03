import 'app_lock_repository.dart';
import 'lock_attempt_policy.dart';

/// アプリロックの状態と検証を担うロジック。
class AppLockService {
  final AppLockRepository _repository;
  final DateTime Function() _now;

  AppLockService(this._repository, {DateTime Function() now = DateTime.now})
      : _now = now;

  /// ロック中か。
  bool get isLocked => _repository.isEnabled();

  /// 復帰時の再施錠猶予。
  Duration get relockGrace =>
      Duration(seconds: _repository.getRelockGraceSeconds());

  /// 復帰時の再施錠猶予を保存する（負値は ArgumentError）。
  Future<void> setRelockGrace(Duration grace) async {
    if (grace.isNegative) {
      throw ArgumentError.value(grace, 'grace', '負の猶予は指定できない');
    }
    await _repository.setRelockGraceSeconds(grace.inSeconds);
  }

  /// 現在ロックアウト中か。
  bool get isLockedOut =>
      LockAttemptPolicy.isLockedOut(_repository.getLockedUntil(), _now());

  /// ロックアウト残り秒数。
  int get lockoutRemainingSeconds =>
      LockAttemptPolicy.remainingSeconds(_repository.getLockedUntil(), _now());

  /// ロックを解除する。パスコード方式なら照合、生体認証方式なら
  /// authenticate 委譲結果で判定。ロックアウト中は照合せず false。
  Future<bool> unlock({
    String? passcode,
    bool biometricSucceeded = false,
  }) async {
    if (!_repository.isEnabled()) return true;
    if (isLockedOut) return false;
    final bool ok;
    switch (_repository.getMethod()) {
      case AppLockMethod.none:
        return true;
      case AppLockMethod.passcode:
        if (passcode == null) {
          await _registerFailure();
          return false;
        }
        ok = _repository.verifyPasscode(passcode);
      case AppLockMethod.biometric:
        ok = biometricSucceeded;
    }
    if (ok) {
      await _repository.resetAttempts();
      return true;
    }
    await _registerFailure();
    return false;
  }

  /// 失敗を記録し、必要ならロックアウトを設定する。
  Future<void> _registerFailure() async {
    final attempts = _repository.getFailedAttempts() + 1;
    await _repository.setFailedAttempts(attempts);
    final lockout = LockAttemptPolicy.lockoutFor(attempts);
    if (lockout > Duration.zero) {
      await _repository.setLockedUntil(_now().add(lockout));
    }
  }

  /// パスコード方式でロックを有効化する（4桁の数字以外は ArgumentError）。
  Future<void> enableWithPasscode(String passcode) async {
    if (passcode.length != 4) {
      throw ArgumentError.value(passcode, 'passcode', '4桁の数字を指定せよ');
    }
    if (int.tryParse(passcode) == null) {
      throw ArgumentError.value(passcode, 'passcode', '数字のみ');
    }
    await _repository.setPasscode(passcode);
    await _repository.setMethod(AppLockMethod.passcode);
    await _repository.setEnabled(true);
  }

  /// ロックを無効化し、パスコードも消去する。
  Future<void> disable() async {
    await _repository.setEnabled(false);
    await _repository.clearPasscode();
    await _repository.setMethod(AppLockMethod.none);
    await _repository.resetAttempts();
  }
}
