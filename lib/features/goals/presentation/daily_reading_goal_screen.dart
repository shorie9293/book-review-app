/// 読書の日次目標設定・進捗画面。
///
/// 今日の進捗・ストリーク・直近7日の達成状況を表示し、
/// 日次目標（分）を保存・解除できる。
library;

import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/goals/data/daily_reading_goal_repository.dart';
import 'package:book_review_app/features/goals/domain/daily_reading_goal.dart';
import 'package:book_review_app/features/goals/domain/daily_reading_goal_service.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// プリセット（分）
const List<int> _presetMinutes = <int>[15, 30, 45, 60, 90];

class DailyReadingGoalScreen extends StatefulWidget {
  /// 試練用の目標リポジトリ差し替え口（null なら Hive 実装）
  final DailyReadingGoalRepository? goalRepositoryOverride;

  /// 試練用のセッションリポジトリ差し替え口（null なら Hive 実装）
  final ReadingSessionRepository? sessionRepositoryOverride;

  final DateTime Function() now;

  const DailyReadingGoalScreen({
    super.key,
    this.goalRepositoryOverride,
    this.sessionRepositoryOverride,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  @override
  State<DailyReadingGoalScreen> createState() => _DailyReadingGoalScreenState();
}

class _DailyReadingGoalScreenState extends State<DailyReadingGoalScreen> {
  late final DailyReadingGoalRepository _goalRepository;
  late final ReadingSessionRepository _sessionRepository;
  final TextEditingController _minutesController = TextEditingController();

  DailyGoalProgress? _progress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _goalRepository =
        widget.goalRepositoryOverride ?? HiveDailyReadingGoalRepository();
    _sessionRepository =
        widget.sessionRepositoryOverride ?? HiveReadingSessionRepository();
    _reload();
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final goal = await _goalRepository.load();
    final sessions = await _sessionRepository.loadAll();
    if (!mounted) return;
    setState(() {
      _progress = DailyReadingGoalService.build(
        sessions: sessions,
        goal: goal,
        now: widget.now(),
      );
      _loading = false;
    });
  }

  Future<void> _save(int targetMinutes) async {
    await _goalRepository.save(
      DailyReadingGoal(
        targetMinutes: targetMinutes,
        updatedAt: widget.now().toUtc().toIso8601String(),
      ),
    );
    await _reload();
  }

  void _onSavePressed() {
    final text = _minutesController.text.trim();
    final value = int.tryParse(text);
    if (value == null || value <= 0) return;
    _save(value);
  }

  String _formatDate(String isoDate) {
    // 'YYYY-MM-DD' → 'MM/DD'
    final parts = isoDate.split('-');
    if (parts.length < 3) return isoDate;
    return '${parts[1]}/${parts[2]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('daily_goal_screen'),
      appBar: AppBar(
        title: const Text('読書の日次目標'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTodayCard(),
                const SizedBox(height: 16),
                _buildStreakLabel(),
                const SizedBox(height: 16),
                _buildLastSevenDays(),
                const SizedBox(height: 24),
                _buildGoalEditor(),
              ],
            ),
    );
  }

  Widget _buildTodayCard() {
    final progress = _progress!;
    return Card(
      key: AppKeys.dailyGoalTodayCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (progress.isSet)
              Text('今日 ${progress.todayMinutes}分 / 目標 ${progress.target}分')
            else
              Text(
                '目標未設定',
                key: AppKeys.dailyGoalEmpty,
              ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              key: AppKeys.dailyGoalProgressBar,
              value: progress.todayRatio,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakLabel() {
    final progress = _progress!;
    return Text(
      '連続 ${progress.currentStreak}日達成（最長 ${progress.longestStreak}日）',
      key: AppKeys.dailyGoalStreakLabel,
    );
  }

  Widget _buildLastSevenDays() {
    final days = List.of(_progress!.lastSevenDays)
      ..sort((a, b) => a.date.compareTo(b.date));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final day in days)
          Expanded(
            child: Container(
              key: AppKeys.dailyGoalDayCell(day.date),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: day.isAchieved
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    _formatDate(day.date),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    '${day.minutes}分',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGoalEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('目標を設定', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final minutes in _presetMinutes)
              ActionChip(
                key: AppKeys.dailyGoalPresetChip(minutes),
                label: Text('$minutes分'),
                onPressed: () {
                  _minutesController.text = '$minutes';
                  _save(minutes);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SemanticHelper.textField(
                testId: 'daily_goal_minutes',
                label: '日次目標の読書分数',
                child: TextField(
                  key: AppKeys.dailyGoalMinutesField,
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '目標（分）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SemanticHelper.interactive(
              testId: 'daily_goal_save',
              label: '日次目標を保存する',
              child: ElevatedButton(
                key: AppKeys.dailyGoalSaveButton,
                onPressed: _onSavePressed,
                child: const Text('保存'),
              ),
            ),
            const SizedBox(width: 8),
            SemanticHelper.interactive(
              testId: 'daily_goal_clear',
              label: '日次目標を解除する',
              child: OutlinedButton(
                key: AppKeys.dailyGoalClearButton,
                onPressed: () => _save(0),
                child: const Text('目標を解除'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
