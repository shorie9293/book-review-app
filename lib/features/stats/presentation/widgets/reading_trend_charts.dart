import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';

/// 月ラベル（'1'..'12'）を描画するタイトルウィジェット。
Widget _monthTitle(double value, TitleMeta meta) {
  return SideTitleWidget(
    meta: meta,
    space: 4,
    child: Text(
      '${value.toInt() + 1}',
      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
    ),
  );
}

FlTitlesData _titlesData({bool showLeft = true}) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(showTitles: showLeft, reservedSize: 32),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        interval: 1,
        getTitlesWidget: _monthTitle,
      ),
    ),
  );
}

/// 月別読了冊数の棒グラフ。
class MonthlyFinishedBarChart extends StatelessWidget {
  /// 長さ12の月別読了冊数（index 0 = 1月）。
  final List<int> monthlyFinished;

  const MonthlyFinishedBarChart({super.key, required this.monthlyFinished});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      key: AppKeys.readingTrendFinishedChart,
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: BarChart(
          BarChartData(
            barGroups: [
              for (var i = 0; i < 12; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: monthlyFinished[i].toDouble(),
                      width: 12,
                      color: color,
                    ),
                  ],
                ),
            ],
            titlesData: _titlesData(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
          // 試練の pumpAndSettle がタイムアウトしないようアニメーションを無効化。
          duration: Duration.zero,
        ),
      ),
    );
  }
}

/// 月別読書時間（分）の折れ線グラフ。
class MonthlyMinutesLineChart extends StatelessWidget {
  /// 長さ12の月別読書時間（index 0 = 1月）。
  final List<int> monthlyMinutes;

  const MonthlyMinutesLineChart({super.key, required this.monthlyMinutes});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      key: AppKeys.readingTrendMinutesChart,
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < 12; i++)
                    FlSpot(i.toDouble(), monthlyMinutes[i].toDouble()),
                ],
                color: color,
                dotData: const FlDotData(show: true),
              ),
            ],
            titlesData: _titlesData(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            minX: 0,
            maxX: 11,
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}

/// ジャンル分布の円グラフ。
class GenreDistributionPieChart extends StatelessWidget {
  /// 正規化ジャンル → 冊数。
  final Map<String, int> genreCounts;

  const GenreDistributionPieChart({super.key, required this.genreCounts});

  @override
  Widget build(BuildContext context) {
    final palette = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    var index = 0;
    final sections = genreCounts.entries.map((entry) {
      final color = palette[index % palette.length];
      index++;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: entry.key,
        color: color,
        radius: 48,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return SizedBox(
      key: AppKeys.readingTrendGenreChart,
      height: 200,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 32,
            sectionsSpace: 2,
            pieTouchData: PieTouchData(enabled: false),
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}