/// 読書習慣ヒートマップの集計結果モデル（純粋・I/O なし）。
library;

import 'package:book_review_app/features/reading/domain/reading_habit_heatmap_service.dart';

/// 曜日×時間帯（4時間刻み）の読書量セル。
class ReadingHabitCell {
  /// 1=月 .. 7=日（DateTime.weekday と同値）。
  final int weekday;

  /// 0..5（0=0-3時, 1=4-7時, 2=8-11時, 3=12-15時, 4=16-19時, 5=20-23時）。
  final int slot;

  /// 合計読書時間（分・0以上）。
  final int minutes;

  const ReadingHabitCell({
    required this.weekday,
    required this.slot,
    required this.minutes,
  });

  /// 記録の無いセルかどうか。
  bool get isEmpty => minutes <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingHabitCell &&
          other.weekday == weekday &&
          other.slot == slot &&
          other.minutes == minutes;

  @override
  int get hashCode => Object.hash(weekday, slot, minutes);

  @override
  String toString() =>
      'ReadingHabitCell(weekday: $weekday, slot: $slot, minutes: $minutes)';
}

/// 曜日×時間帯ヒートマップの集計結果（7曜日×6時間帯=42セル・常にゼロ埋め）。
class ReadingHabitHeatmap {
  /// 42件。index = (weekday-1)*6 + slot。
  final List<ReadingHabitCell> cells;

  /// 最大セルの分（全0なら0）。
  final int maxMinutes;

  /// 合計分。
  final int totalMinutes;

  /// 集計に含めたセッション数。
  final int totalSessions;

  /// 曜日合計が最大の曜日（同数は曜日番号が小さい方=月優先）。記録なしは null。
  final int? busiestWeekday;

  /// 時間帯合計が最大の slot（同数は slot が小さい方）。記録なしは null。
  final int? busiestSlot;

  const ReadingHabitHeatmap({
    required this.cells,
    required this.maxMinutes,
    required this.totalMinutes,
    required this.totalSessions,
    required this.busiestWeekday,
    required this.busiestSlot,
  });

  /// 記録が一つも無いかどうか。
  bool get isEmpty => totalSessions == 0;

  /// 指定曜日・時間帯のセルを返す（weekday: 1..7, slot: 0..5）。
  ReadingHabitCell cellAt(int weekday, int slot) =>
      cells[(weekday - 1) * ReadingHabitHeatmapService.slotCount + slot];

  /// 0..4 の濃淡レベル。
  /// 0分→0, max<=0→0, ratio=minutes/max, <=0.25→1, <=0.5→2, <=0.75→3, else 4。
  int levelOf(ReadingHabitCell cell) {
    if (cell.minutes <= 0) return 0;
    if (maxMinutes <= 0) return 0;
    final ratio = cell.minutes / maxMinutes;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  /// 曜日ごとの合計分（長さ7・index0=月曜）。
  List<int> get weekdayTotals => [
        for (var w = 1; w <= 7; w++)
          [
            for (var s = 0; s < ReadingHabitHeatmapService.slotCount; s++)
              cellAt(w, s).minutes,
          ].fold<int>(0, (sum, m) => sum + m),
      ];

  /// 時間帯ごとの合計分（長さ6）。
  List<int> get slotTotals => [
        for (var s = 0; s < ReadingHabitHeatmapService.slotCount; s++)
          [
            for (var w = 1; w <= 7; w++) cellAt(w, s).minutes,
          ].fold<int>(0, (sum, m) => sum + m),
      ];

  /// 最も読書した曜日と時間帯の表示。例 '火曜 20-23時' / 記録なければ '—'。
  String get busiestLabel => busiestWeekday == null || busiestSlot == null
      ? '—'
      : '${ReadingHabitHeatmapService.weekdayLabel(busiestWeekday!)}曜 '
          '${ReadingHabitHeatmapService.slotLabel(busiestSlot!)}';
}
