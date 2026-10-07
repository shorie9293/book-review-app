import 'dart:async';

import 'package:flutter/material.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/domain/reading_session_service.dart';
import 'package:book_review_app/features/reading/domain/reading_stats.dart';
import 'package:book_review_app/features/reading/presentation/widgets/reading_habit_heatmap.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 読書時間画面。
///
/// タイマーで読書セッションを記録し、統計・直近7日・履歴を表示する。
/// repository / now を注入できるため、実 Hive・実時刻に触れずに検証できる。
class ReadingSessionScreen extends StatefulWidget {
  final ReadingSessionRepository repository;

  /// 現在時刻の取得関数（試練では固定時刻を注入する）。
  final DateTime Function() now;

  /// 集計・生成に使う純粋サービス。
  final ReadingSessionService service;

  const ReadingSessionScreen({
    super.key,
    required this.repository,
    DateTime Function()? now,
    this.service = const ReadingSessionService(),
  })  : now = now ?? DateTime.now;

  @override
  State<ReadingSessionScreen> createState() => _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends State<ReadingSessionScreen> {
  List<ReadingSession> _sessions = [];
  bool _isLoading = true;
  String? _loadError;

  /// タイマー起動中の開始時刻（null なら未起動）。
  DateTime? _startedAt;

  /// 停止済みで未保存の確定分数（null なら保存待ちなし）。
  int? _pendingMinutes;

  Timer? _tickTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    List<ReadingSession> sessions;
    try {
      sessions = await widget.repository.loadAll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sessions = [];
        _isLoading = false;
        _loadError = '読み込みに失敗しました: $error';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
      _loadError = null;
    });
  }

  void _startTimer() {
    setState(() {
      _startedAt = widget.now();
      _pendingMinutes = null;
      _elapsedSeconds = 0;
    });
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds =
            widget.now().difference(_startedAt!).inSeconds.clamp(0, 1 << 31);
      });
    });
  }

  /// 停止：経過分（最低1分）を確定し、保存待ちにする。
  void _stopTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (_startedAt == null) return;
    final minutes = widget.service
        .elapsedMinutes(_startedAt!, widget.now())
        .clamp(1, 1 << 31);
    setState(() {
      _pendingMinutes = minutes;
      _startedAt = null;
      _elapsedSeconds = 0;
    });
  }

  /// 確定した経過分をセッションとして保存する。
  Future<void> _savePending() async {
    final pending = _pendingMinutes;
    if (pending == null) return;
    final startedAt = widget.now().subtract(Duration(minutes: pending));
    final session = widget.service.fromInterval(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(minutes: pending)),
    );
    await widget.repository.add(session);
    if (!mounted) return;
    setState(() {
      _pendingMinutes = null;
    });
    await _reload();
  }

  /// 手動追加ダイアログを開く。
  Future<void> _openManualAddDialog() async {
    final titleController = TextEditingController();
    final minutesController = TextEditingController();
    String? errorMessage;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('読書時間を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('reading_manual_title_field'),
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '書名（任意）',
                ),
              ),
              TextField(
                key: const Key('reading_manual_minutes_field'),
                controller: minutesController,
                decoration: const InputDecoration(
                  labelText: '読書時間（分）',
                ),
                keyboardType: TextInputType.number,
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final minutes = int.tryParse(minutesController.text.trim());
                if (minutes == null || minutes <= 0) {
                  setDialogState(() {
                    errorMessage = '読書時間は正の整数で入力してください';
                  });
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final minutes = int.tryParse(minutesController.text.trim());
    if (minutes == null || minutes <= 0) return;

    final title = titleController.text.trim();
    final now = widget.now();
    final session = widget.service.fromInterval(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookTitle: title.isEmpty ? null : title,
      startedAt: now,
      endedAt: now.add(Duration(minutes: minutes)),
    );
    await widget.repository.add(session);
    await _reload();
  }

  Future<void> _removeSession(ReadingSession session) async {
    await widget.repository.remove(session.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_reading_session'),
      appBar: AppBar(
        title: const Text('読書時間'),
        actions: [
          IconButton(
            key: AppKeys.readingAddButton,
            icon: const Icon(Icons.add),
            tooltip: '読書時間を手動追加',
            onPressed: _openManualAddDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Text(_loadError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    if (_sessions.isEmpty) {
      // 空状態：記録が無い旨を示しつつ、タイマーはすぐ使えるように残す。
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            key: AppKeys.readingEmpty,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Text('まだ記録がありません'),
            ),
          ),
          _buildTimerSection(),
        ],
      );
    }

    final stats = widget.service.summarize(_sessions);
    final daily = widget.service.recentDailyTotals(_sessions, widget.now());
    final sorted = widget.service.sortByRecent(_sessions);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTimerSection(),
        const SizedBox(height: 16),
        _buildStatsSection(stats),
        const SizedBox(height: 16),
        _buildDailySection(daily),
        const SizedBox(height: 16),
        _buildHistorySection(sorted),
        const SizedBox(height: 16),
        ReadingHabitHeatmap(sessions: sorted),
      ],
    );
  }

  Widget _buildTimerSection() {
    final running = _startedAt != null;
    final pending = _pendingMinutes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (running)
              Text(
                _formatElapsed(_elapsedSeconds),
                key: AppKeys.readingElapsed,
                style: Theme.of(context).textTheme.headlineMedium,
              )
            else if (pending != null)
              Text(
                '${pending}分が確定しました',
                style: Theme.of(context).textTheme.titleMedium,
              )
            else
              Text('読書を記録しましょう',
                  style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SemanticHelper.interactive(
              testId: running ? 'reading_stop' : 'reading_start',
              label: running ? '読書タイマーを停止する' : '読書タイマーを開始する',
              child: FilledButton(
                key: running || pending != null
                    ? AppKeys.readingStop
                    : AppKeys.readingStart,
                onPressed: pending != null ? _savePending : (running ? _stopTimer : _startTimer),
                child: Text(pending != null ? '保存' : (running ? '停止' : '開始')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildStatsSection(ReadingStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('統計', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCell('総読書時間', stats.totalLabel,
                    key: AppKeys.readingTotalLabel),
                _statCell('セッション数', '${stats.sessionCount}回'),
                _statCell('読んだ本', '${stats.bookCount}冊'),
                _statCell('活動日数', '${stats.activeDays}日'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String label, String value, {Key? key}) {
    return Column(
      children: [
        Text(value, key: key, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildDailySection(List<DailyReadingTotal> daily) {
    final maxMinutes =
        daily.map((d) => d.minutes).fold<int>(0, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('直近7日', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final day in daily)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(_dayLabel(day.day)),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value:
                            maxMinutes == 0 ? 0 : day.minutes / maxMinutes,
                        minHeight: 10,
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text('${day.minutes}分',
                          textAlign: TextAlign.end),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime day) {
    return '${day.month}/${day.day}';
  }

  Widget _buildHistorySection(List<ReadingSession> sorted) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('履歴', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (sorted.isEmpty)
              const Text('まだ記録がありません')
            else
              for (final session in sorted)
                ListTile(
                  key: AppKeys.readingSessionRow(session.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(session.bookTitle ?? '(紐づけなし)'),
                  subtitle: Text(
                      '${_formatStartedAt(session.startedAt)}・${session.durationLabel}'),
                  trailing: SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        'reading_delete', session.id),
                    label: '読書セッション「${session.bookTitle ?? '(紐づけなし)'}」を削除',
                    child: IconButton(
                      key: Key('reading_delete_${session.id}'),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '削除',
                      onPressed: () => _removeSession(session),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _formatStartedAt(DateTime at) {
    final month = at.month.toString().padLeft(2, '0');
    final day = at.day.toString().padLeft(2, '0');
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
