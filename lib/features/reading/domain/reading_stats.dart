/// 読書セッションの集計統計（不変・純粋な値オブジェクト）。
class ReadingStats {
  final int totalMinutes;
  final int sessionCount;

  /// 異なる bookId 数（bookId が null のセッションは除外）。
  final int bookCount;

  /// セッションのある日数（日付でユニーク）。
  final int activeDays;

  const ReadingStats({
    required this.totalMinutes,
    required this.sessionCount,
    required this.bookCount,
    required this.activeDays,
  });

  const ReadingStats.empty()
      : totalMinutes = 0,
        sessionCount = 0,
        bookCount = 0,
        activeDays = 0;

  bool get isEmpty =>
      totalMinutes == 0 &&
      sessionCount == 0 &&
      bookCount == 0 &&
      activeDays == 0;

  /// 総読書時間ラベル（'12時間30分' / '45分' / '0分'）。
  String get totalLabel {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes分';
    if (minutes == 0) return '$hours時間';
    return '$hours時間$minutes分';
  }

  /// 1セッションあたりの平均読書時間（分）。sessionCount==0 は 0.0。
  double get averageMinutesPerSession =>
      sessionCount == 0 ? 0.0 : totalMinutes / sessionCount;
}
