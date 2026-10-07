/// 読書セッションから曜日×時間帯のヒートマップを集計する純粋ドメインサービス。
///
/// Widget / Hive / Riverpod に依存せず、引数のセッションリストからのみ集計する。
/// 空リストでも例外を投げず、常にゼロ埋め42セルを返す。
library;

import 'package:book_review_app/features/reading/domain/reading_habit_heatmap.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

class ReadingHabitHeatmapService {
  const ReadingHabitHeatmapService._();

  /// 各時間帯の幅（時間）。
  static const int slotHours = 4;

  /// 時間帯の数（24 / slotHours）。
  static const int slotCount = 6;

  /// hour を 0..23 に clamp したうえで slot (0..5) に変換する。
  static int slotOfHour(int hour) {
    final h = hour.clamp(0, 23);
    return h ~/ slotHours;
  }

  /// slot の表示ラベル（'0-3時' … '20-23時'・範囲外は '—'）。
  static String slotLabel(int slot) {
    if (slot < 0 || slot >= slotCount) return '—';
    final start = slot * slotHours;
    final end = start + slotHours - 1;
    return '$start-$end時';
  }

  /// 曜日の表示ラベル（1->'月' … 7->'日'・範囲外は '—'）。
  static String weekdayLabel(int weekday) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    if (weekday < 1 || weekday > 7) return '—';
    return labels[weekday - 1];
  }

  /// セッション群からヒートマップを集計する。
  ///
  /// 各セッションの [ReadingSession.startedAt] の曜日・時刻帯のセルに
  /// [ReadingSession.durationMinutes] を加算する。durationMinutes <= 0 は
  /// 0 として扱い例外を投げない（モデル上あり得ないが防御）。
  /// 合計が0分のとき busiest はともに null。
  static ReadingHabitHeatmap build({required List<ReadingSession> sessions}) {
    final minutes = List<int>.filled(7 * slotCount, 0);
    var totalSessions = 0;
    var totalMinutes = 0;
    for (final session in sessions) {
      totalSessions += 1;
      final dm = session.durationMinutes;
      final mins = dm > 0 ? dm : 0;
      final weekday = session.startedAt.weekday;
      final slot = slotOfHour(session.startedAt.hour);
      minutes[(weekday - 1) * slotCount + slot] += mins;
      totalMinutes += mins;
    }
    final maxMinutes = minutes.fold<int>(0, (m, v) => v > m ? v : m);

    // 曜日合計が最大の曜日（同数は小さい番号=月優先）。
    var busiestWeekday = 1;
    var weekdayBest = -1;
    for (var w = 1; w <= 7; w++) {
      var total = 0;
      for (var s = 0; s < slotCount; s++) {
        total += minutes[(w - 1) * slotCount + s];
      }
      if (total > weekdayBest) {
        weekdayBest = total;
        busiestWeekday = w;
      }
    }
    // 時間帯合計が最大の slot（同数は小さい slot）。
    var busiestSlot = 0;
    var slotBest = -1;
    for (var s = 0; s < slotCount; s++) {
      var total = 0;
      for (var w = 1; w <= 7; w++) {
        total += minutes[(w - 1) * slotCount + s];
      }
      if (total > slotBest) {
        slotBest = total;
        busiestSlot = s;
      }
    }
    final hasRecord = totalMinutes > 0;
    return ReadingHabitHeatmap(
      cells: [
        for (var w = 1; w <= 7; w++)
          for (var s = 0; s < slotCount; s++)
            ReadingHabitCell(
              weekday: w,
              slot: s,
              minutes: minutes[(w - 1) * slotCount + s],
            ),
      ],
      maxMinutes: maxMinutes,
      totalMinutes: totalMinutes,
      totalSessions: totalSessions,
      busiestWeekday: hasRecord ? busiestWeekday : null,
      busiestSlot: hasRecord ? busiestSlot : null,
    );
  }
}
