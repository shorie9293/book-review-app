import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reminder/data/reading_reminder_repository.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_schedule_service.dart';
import 'package:book_review_app/features/reminder/domain/reading_reminder_settings.dart';
import 'package:book_review_app/features/reminder/infrastructure/reading_reminder_scheduler.dart';

/// 読書リマインダーの設定画面。
class ReadingReminderSettingsScreen extends StatefulWidget {
  const ReadingReminderSettingsScreen({
    super.key,
    ReadingReminderRepository? repository,
    ReadingReminderScheduler? scheduler,
    DateTime Function()? now,
  })  : _repository = repository,
        _scheduler = scheduler,
        _now = now;

  final ReadingReminderRepository? _repository;
  final ReadingReminderScheduler? _scheduler;
  final DateTime Function()? _now;

  @override
  State<ReadingReminderSettingsScreen> createState() =>
      _ReadingReminderSettingsScreenState();
}

class _ReadingReminderSettingsScreenState
    extends State<ReadingReminderSettingsScreen> {
  static const _scheduleService = ReadingReminderScheduleService();
  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  late final ReadingReminderRepository _repository;
  late final ReadingReminderScheduler _scheduler;
  late final DateTime Function() _now;

  bool _loading = true;
  ReadingReminderSettings _settings = ReadingReminderSettings.defaults();

  @override
  void initState() {
    super.initState();
    _repository = widget._repository ?? HiveReadingReminderRepository();
    _scheduler =
        widget._scheduler ?? NotificationServiceReadingReminderScheduler();
    _now = widget._now ?? DateTime.now;
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.readingReminderScreen,
      appBar: AppBar(title: const Text('読書リマインダー')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '決めた時刻に読書を促す通知をお届けします。'
                  '曜日と時刻を自由に設定できます。',
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: AppKeys.readingReminderEnabledSwitch,
                  title: const Text('読書リマインダー'),
                  subtitle: const Text('毎日の読書の時刻に通知します'),
                  value: _settings.enabled,
                  onChanged: (value) =>
                      setState(() => _settings = _settings.copyWith(enabled: value)),
                ),
                ListTile(
                  key: AppKeys.readingReminderTimeButton,
                  title: const Text('通知時刻'),
                  trailing: Text(_scheduleService.timeLabel(
                      _settings.hour, _settings.minute)),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var weekday = 1; weekday <= 7; weekday++)
                      FilterChip(
                        key: AppKeys.readingReminderWeekdayChip(weekday),
                        label: Text(_weekdayLabels[weekday - 1]),
                        selected: _settings.weekdays.contains(weekday),
                        onSelected: (selected) => _toggleWeekday(weekday, selected),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('次回の通知'),
                  subtitle: Text(
                    _nextLabel(),
                    key: AppKeys.readingReminderNextLabel,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  key: AppKeys.readingReminderSaveButton,
                  onPressed: _save,
                  child: const Text('保存'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: AppKeys.readingReminderTestButton,
                  onPressed: _sendTest,
                  child: const Text('テスト通知'),
                ),
                const SizedBox(height: 24),
                const Text(
                  '通知が届かない場合は端末の設定で通知を許可してください',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }

  String _nextLabel() {
    if (!_settings.enabled) return '通知は無効です';
    if (_settings.weekdays.isEmpty) return '通知日が未選択です';
    final next = _scheduleService.nextOccurrence(_settings, _now());
    if (next == null) return '通知は無効です';
    final y = next.year.toString().padLeft(4, '0');
    final m = next.month.toString().padLeft(2, '0');
    final d = next.day.toString().padLeft(2, '0');
    final hh = next.hour.toString().padLeft(2, '0');
    final mm = next.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  void _toggleWeekday(int weekday, bool selected) {
    final set = Set<int>.from(_settings.weekdays);
    if (selected) {
      set.add(weekday);
    } else {
      set.remove(weekday);
    }
    final sorted = set.toList()..sort();
    setState(() => _settings = _settings.copyWith(weekdays: sorted));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _settings.hour, minute: _settings.minute),
    );
    if (picked == null) return;
    setState(() => _settings =
        _settings.copyWith(hour: picked.hour, minute: picked.minute));
  }

  Future<void> _save() async {
    await _repository.save(_settings);
    await _scheduler.apply(_settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('保存しました')));
  }

  Future<void> _sendTest() async {
    try {
      await _scheduler.sendTestNotification();
    } catch (_) {
      // テスト通知の失敗で画面がクラッシュしないよう握り潰す。
    }
  }
}
