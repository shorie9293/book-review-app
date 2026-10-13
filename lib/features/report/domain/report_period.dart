/// 期間レポート機能の期間モデル。
///
/// 週次（月曜始まり・7日間）または月次の集計期間を表す不変モデル。
/// 期間の境界は常にローカル時刻の 0 時 0 分 0 秒に正規化される。
enum ReportRange {
  /// 週次（月曜始まり）
  week,

  /// 月次
  month;

  /// 画面表示用のラベル。
  String get label => switch (this) {
        ReportRange.week => '週次',
        ReportRange.month => '月次',
      };
}

/// 集計期間（開始 0 時から翌期間開始 0 時までの排他区間）。
class ReportPeriod {
  /// 期間の種別。
  final ReportRange range;

  /// 期間初日の 00:00（ローカル）。
  final DateTime start;

  /// 期間翌日の 00:00（ローカル・排他）。この時刻自体は期間に含まれない。
  final DateTime endExclusive;

  ReportPeriod({
    required this.range,
    required this.start,
    required this.endExclusive,
  }) {
    if (!start.isBefore(endExclusive)) {
      throw ArgumentError.value(
        endExclusive,
        'endExclusive',
        'endExclusive は start より後でなければならない',
      );
    }
    if (!_isMidnight(start)) {
      throw ArgumentError.value(start, 'start', 'start は 0時0分0秒でなければならない');
    }
    if (!_isMidnight(endExclusive)) {
      throw ArgumentError.value(
        endExclusive,
        'endExclusive',
        'endExclusive は 0時0分0秒でなければならない',
      );
    }
  }

  static bool _isMidnight(DateTime d) =>
      d.hour == 0 && d.minute == 0 && d.second == 0;

  /// [date] の属する週（月曜始まり・7日間）の期間を返す。
  factory ReportPeriod.weekOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    // weekday: 月=1〜日=7 → 月曜までの日数
    final offset = day.weekday - DateTime.monday;
    final start = day.subtract(Duration(days: offset));
    return ReportPeriod(
      range: ReportRange.week,
      start: start,
      endExclusive: start.add(const Duration(days: 7)),
    );
  }

  /// [date] の属する月（1日 0 時〜翌月1日 0 時）の期間を返す。
  factory ReportPeriod.monthOf(DateTime date) {
    final start = DateTime(date.year, date.month, 1);
    final endExclusive = DateTime(date.year, date.month + 1, 1);
    return ReportPeriod(
      range: ReportRange.month,
      start: start,
      endExclusive: endExclusive,
    );
  }

  /// 期間の日数。
  int get days => endExclusive.difference(start).inDays;

  /// 期間の最終日（0 時）。`endExclusive - 1日`。
  DateTime get endInclusive => endExclusive.subtract(const Duration(days: 1));

  /// 1つ前の期間（week→7日前、month→前月）。
  ReportPeriod previous() => switch (range) {
        ReportRange.week => ReportPeriod.weekOf(
            start.subtract(const Duration(days: 7)),
          ),
        ReportRange.month => ReportPeriod.monthOf(
            DateTime(start.year, start.month - 1, 1),
          ),
      };

  /// 1つ後の期間（week→7日後、month→翌月）。
  ReportPeriod next() => switch (range) {
        ReportRange.week =>
          ReportPeriod.weekOf(start.add(const Duration(days: 7))),
        ReportRange.month => ReportPeriod.monthOf(
            DateTime(start.year, start.month + 1, 1),
          ),
      };

  /// [d] が期間に含まれるか（start は含む、endExclusive は含まない）。
  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(endExclusive);

  /// 画面表示用ラベル。
  ///
  /// - week: `2026年10月12日〜10月18日`（終端は同年なら年を省略）
  ///   年跨ぎは `2025年12月29日〜2026年1月4日`。
  /// - month: `2026年10月`
  String get label => switch (range) {
        ReportRange.week => start.year == endInclusive.year
            ? '${_full(start)}〜${_md(endInclusive)}'
            : '${_full(start)}〜${_full(endInclusive)}',
        ReportRange.month => '${start.year}年${start.month}月',
      };

  static String _full(DateTime d) => '${d.year}年${d.month}月${d.day}日';

  static String _md(DateTime d) => '${d.month}月${d.day}日';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportPeriod &&
          other.range == range &&
          other.start == start &&
          other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(range, start, endExclusive);

  @override
  String toString() =>
      'ReportPeriod($label, start: $start, endExclusive: $endExclusive)';
}