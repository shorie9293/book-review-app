import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/domain/reading_habit_heatmap.dart'
    as habit_model;
import 'package:book_review_app/features/reading/domain/reading_habit_heatmap_service.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

/// 読書習慣ヒートマップ（曜日×時間帯）の表示ウィジェット。
///
/// repository に依存せず、画面の State からセッションを直接受け取る。
/// セッションが空のときはグリッドを出さず空メッセージのみ表示する。
class ReadingHabitHeatmap extends StatelessWidget {
  final List<ReadingSession> sessions;

  const ReadingHabitHeatmap({super.key, required this.sessions});

  /// 濃淡5段階（level 0..4）の静的パレット。alpha 計算で範囲外を出さない表引き。
  static const List<Color> palette = [
    Color(0x141976D2), // level 0: 記録なし（淡色）
    Color(0x5590CAF9), // level 1
    Color(0x9964B5F6), // level 2
    Color(0xCC1E88E5), // level 3
    Color(0xFF0D47A1), // level 4
  ];

  @override
  Widget build(BuildContext context) {
    final heatmap = ReadingHabitHeatmapService.build(sessions: sessions);
    if (heatmap.isEmpty) {
      return Container(
        key: AppKeys.readingHabitHeatmap,
        child: const Text(
          'まだ読書の記録がありません',
          key: AppKeys.readingHabitEmpty,
        ),
      );
    }
    return Container(
      key: AppKeys.readingHabitHeatmap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🕐 読書のリズム',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'よく読む時間: ${heatmap.busiestLabel}／'
                '合計 ${heatmap.totalMinutes}分・${heatmap.totalSessions}回',
                key: AppKeys.readingHabitBusiest,
              ),
              const SizedBox(height: 12),
              _buildGrid(context, heatmap),
              const SizedBox(height: 12),
              _buildLegend(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    habit_model.ReadingHabitHeatmap heatmap,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        key: AppKeys.readingHabitGrid,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 時間帯ラベル行。
          Row(
            children: [
              const SizedBox(width: 24),
              for (var s = 0; s < ReadingHabitHeatmapService.slotCount; s++)
                SizedBox(
                  width: 40,
                  child: Text(
                    ReadingHabitHeatmapService.slotLabel(s),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
          // 曜日ごとの行。
          for (var w = 1; w <= 7; w++)
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    ReadingHabitHeatmapService.weekdayLabel(w),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (var s = 0; s < ReadingHabitHeatmapService.slotCount; s++)
                  _buildCell(context, heatmap, heatmap.cellAt(w, s)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    habit_model.ReadingHabitHeatmap heatmap,
    habit_model.ReadingHabitCell cell,
  ) {
    final level = heatmap.levelOf(cell).clamp(0, 4);
    return Container(
      key: AppKeys.readingHabitCell(cell.weekday, cell.slot),
      width: 36,
      height: 24,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: palette[level],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      key: AppKeys.readingHabitLegend,
      children: [
        Text('少', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 4),
        for (final color in palette)
          Container(
            width: 16,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: 4),
        Text('多', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
