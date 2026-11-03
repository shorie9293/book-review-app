/// 失敗試行回数に基づくロックアウト判定（純粋ロジック・時刻は引数注入）。
class LockAttemptPolicy {
  const LockAttemptPolicy._();

  /// 無料で試せる回数。これ未満ではロックアウトしない。
  static const int maxFreeAttempts = 5;

  /// 最初のロックアウト時間。
  static const Duration baseLockout = Duration(seconds: 30);

  /// ロックアウトの上限。
  static const Duration maxLockout = Duration(minutes: 15);

  /// 現在ロックアウト中か。
  static bool isLockedOut(DateTime? lockedUntil, DateTime now) {
    if (lockedUntil == null) return false;
    return lockedUntil.isAfter(now);
  }

  /// 失敗回数 [failedAttempts] に対するロックアウト時間。
  static Duration lockoutFor(int failedAttempts) {
    if (failedAttempts < maxFreeAttempts) return Duration.zero;
    var seconds = baseLockout.inSeconds;
    var steps = (failedAttempts - maxFreeAttempts) ~/ maxFreeAttempts;
    while (steps > 0 && seconds < maxLockout.inSeconds) {
      seconds *= 2;
      steps--;
    }
    final capped =
        seconds > maxLockout.inSeconds ? maxLockout.inSeconds : seconds;
    return Duration(seconds: capped);
  }

  /// 残り秒数（過去・null は 0、端数は切り上げ）。
  static int remainingSeconds(DateTime? lockedUntil, DateTime now) {
    if (lockedUntil == null) return 0;
    final ms = lockedUntil.difference(now).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms + 999) ~/ 1000;
  }

  /// ロックアウト中の案内文。
  static String lockoutLabel(int remainingSeconds) =>
      'しばらく待ってから再試行してください（残り${remainingSeconds}秒）';
}
