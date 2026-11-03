/// 復帰時の再施錠判定（純粋ロジック・時刻は引数注入）。
class LockReloadPolicy {
  const LockReloadPolicy._();

  /// 設定画面で選べる猶予秒数。
  static const List<int> graceOptionsSeconds = [0, 30, 60, 300];

  /// 猶予秒数の表示ラベル。
  static String graceLabel(int seconds) {
    switch (seconds) {
      case 0:
        return '即時';
      case 30:
        return '30秒';
      case 60:
        return '1分';
      case 300:
        return '5分';
      default:
        return '${seconds}秒';
    }
  }

  /// バックグラウンドから復帰した際に再施錠すべきか。
  ///
  /// - 記録なし: true（施錠）
  /// - 猶予なし: true（即時）
  /// - 猶予内: false
  /// - 猶予超過: true
  /// - 時計巻き戻し（now < backgroundedAt）: true（安全側）
  static bool shouldRelock(
    DateTime? backgroundedAt,
    DateTime now,
    Duration grace,
  ) {
    if (backgroundedAt == null) return true;
    if (grace <= Duration.zero) return true;
    final elapsed = now.difference(backgroundedAt);
    if (elapsed.isNegative) return true;
    return elapsed >= grace;
  }
}
