import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:book_review_app/core/crash/crash_log_entry.dart';
import 'package:book_review_app/core/crash/crash_log_repository.dart';
import 'package:book_review_app/core/crash/crash_log_service.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 端末内クラッシュログの閲覧画面（サマリー＋直近一覧＋コピー）。
///
/// 送信はしない。記録はあくまで端末内に留め、必要な時だけ
/// クリップボードへ写してユーザー自身が報告できるようにする。
class CrashLogScreen extends StatefulWidget {
  /// 読み出し元（未指定なら既定の端末内ログ）。
  final CrashLogRepository? repository;

  /// 一覧に出す最大件数。
  final int limit;

  const CrashLogScreen({super.key, this.repository, this.limit = 20});

  /// 画面の Key。
  static const Key screenKey = Key('crash_log_screen');

  /// コピーボタン。
  static const Key copyKey = Key('crash_log_copy_button');

  /// 空状態の文言。
  static const Key emptyKey = Key('crash_log_empty');

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  List<CrashLogEntry>? _entries;

  CrashLogRepository get _repository =>
      widget.repository ?? defaultCrashLogRepository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _repository.loadAll();
    if (!mounted) return;
    setState(() => _entries = loaded);
  }

  String _formatTime(CrashLogEntry entry) {
    final t = entry.timestamp.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  String _buildClipboardText(List<CrashLogEntry> entries) {
    final buffer = StringBuffer();
    final summary = summarize(entries);
    if (summary != null) buffer.writeln(summary);
    for (final entry in recent(entries, limit: widget.limit)) {
      buffer.writeln('---');
      buffer.writeln('${_formatTime(entry)} [${entry.kind}]');
      buffer.writeln(entry.message);
      if (entry.stackTop.isNotEmpty) buffer.writeln(entry.stackTop);
    }
    return buffer.toString();
  }

  Future<void> _copy() async {
    final entries = _entries ?? const <CrashLogEntry>[];
    if (entries.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _buildClipboardText(entries)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('クリップボードへコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      key: CrashLogScreen.screenKey,
      appBar: AppBar(title: const Text('不具合の報告')),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(entries),
    );
  }

  Widget _buildBody(List<CrashLogEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '記録された不具合はありません',
            key: CrashLogScreen.emptyKey,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final summary = summarize(entries) ?? '';
    final visible = recent(entries, limit: widget.limit);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            summary,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SemanticHelper.interactive(
              testId: 'crash_log_copy',
              label: '不具合の記録をクリップボードへコピー',
              child: OutlinedButton.icon(
                key: CrashLogScreen.copyKey,
                onPressed: _copy,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('クリップボードへコピー'),
              ),
            ),
          ),
        ),
        const Divider(height: 24),
        for (final entry in visible)
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(
              entry.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${_formatTime(entry)}  [${entry.kind}]'),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Text(
            '記録は端末内にのみ保存されます（直近50件）。',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
