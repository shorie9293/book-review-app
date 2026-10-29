/// 暦日（ローカル）の跨ぎ判定の結果。
enum DayRolloverResult {
  /// 同じローカル暦日のまま。
  sameDay,

  /// 暦日が進んだ（日付跨ぎ）。
  rolledOver,

  /// 暦日が巻き戻った（端末時計の後退・タイムゾーン変更など）。
  clockWentBack,
}

/// 前面復帰時に「日付が跨いだか」をローカル暦で判定する。
///
/// UTC とローカルを混ぜると日本時間の朝に誤判定するため、
/// 判定は必ずローカル [DateTime] の年月日で行う。
class DayRolloverDetector {
  DayRolloverDetector({required DateTime lastSeen}) : _lastSeen = lastSeen;

  DateTime _lastSeen;

  /// 直近に観測した日時。
  DateTime get lastSeen => _lastSeen;

  /// [now] を観測し、前回観測からの暦日の変化を返す。
  ///
  /// - 同一暦日: [DayRolloverResult.sameDay]（[lastSeen] を更新）
  /// - 暦日が進んだ: [DayRolloverResult.rolledOver]（[lastSeen] = [now]）
  /// - 暦日が巻き戻った: [DayRolloverResult.clockWentBack]（[lastSeen] 据え置き）
  ///
  /// 時計の後退は例外にせず、据え置き（クランプ）で吸収する。
  DayRolloverResult check(DateTime now) {
    final last = DateTime(_lastSeen.year, _lastSeen.month, _lastSeen.day);
    final current = DateTime(now.year, now.month, now.day);
    final diff = current.difference(last).inDays;

    if (diff == 0) {
      _lastSeen = now;
      return DayRolloverResult.sameDay;
    }
    if (diff > 0) {
      _lastSeen = now;
      return DayRolloverResult.rolledOver;
    }
    // 巻き戻しは据え置き。次に正しい暦日へ戻った時点で rolledOver になる。
    return DayRolloverResult.clockWentBack;
  }
}
