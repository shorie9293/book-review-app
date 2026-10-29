import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_sharer.dart';

/// 自動バックアップの閲覧・復元・共有画面。
///
/// 一覧 → 読み出し → 表示行の組み立てを行い、復元・共有は注入時のみ導線を出す。
/// 壊れた JSON の世代は一覧に出さない（復元できないため）。
class AutoBackupScreen extends StatefulWidget {
  /// 自動バックアップの保管先。
  final AutoBackupStore store;

  /// 自動バックアップの掟（保持世代数）。
  final AutoBackupPolicy policy;

  /// 復元器（null なら復元導線を出さない）。
  final AutoBackupRestorer? restorer;

  /// 共有器（null なら共有導線を出さない）。
  final AutoBackupSharer? sharer;

  /// 「今すぐバックアップ」の処理（null なら導線を出さない）。
  final Future<void> Function()? onBackupNow;

  /// 現在時刻（試練用）。
  final DateTime Function()? now;

  /// 画面を生成する。
  const AutoBackupScreen({
    super.key,
    required this.store,
    this.policy = const AutoBackupPolicy(),
    this.restorer,
    this.sharer,
    this.onBackupNow,
    this.now,
  });

  @override
  State<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends State<AutoBackupScreen> {
  late final AutoBackupPresenter _presenter =
      AutoBackupPresenter(keep: widget.policy.keep);

  bool _loading = true;
  List<AutoBackupRow> _rows = const [];
  Map<String, String?> _contents = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    List<AutoBackupRow> rows = const [];
    Map<String, String?> contents = const {};
    try {
      final entries = await widget.store.list();
      final loaded = <String, String?>{};
      for (final entry in entries) {
        try {
          loaded[entry.fileName] = await widget.store.read(entry.fileName);
        } catch (_) {
          loaded[entry.fileName] = null;
        }
      }
      contents = loaded;
      rows = _presenter
          .buildRows(entries: entries, contents: loaded)
          .where((row) => row.restorable)
          .toList();
    } catch (_) {
      rows = const [];
      contents = const {};
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _contents = contents;
      _loading = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onBackupNowPressed() async {
    final action = widget.onBackupNow;
    if (action == null) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      // 例外は握る（画面は生かしたまま）。
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _reload();
  }

  Future<void> _onRestorePressed(AutoBackupRow row) async {
    final restorer = widget.restorer;
    if (restorer == null || !row.restorable) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('この世代を復元しますか？'),
        content: Text(
          '${row.displayLabel}\n現在のデータは復元前に自動で保存されます。',
        ),
        actions: [
          TextButton(
            key: AppKeys.autoBackupRestoreCancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: AppKeys.autoBackupRestoreConfirm,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await restorer.restore(row.entry.fileName);
      _showMessage(result.message);
    } catch (_) {
      _showMessage('復元に失敗しました');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _reload();
  }

  Future<void> _onSharePressed(AutoBackupRow row) async {
    final sharer = widget.sharer;
    if (sharer == null) return;
    final content = _contents[row.entry.fileName];
    if (content == null) return;
    try {
      await sharer.share(row.entry.fileName, content);
      _showMessage('バックアップを共有しました');
    } catch (_) {
      _showMessage('共有に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRestorer = widget.restorer != null;
    final hasSharer = widget.sharer != null;
    final hasBackupNow = widget.onBackupNow != null;

    return Scaffold(
      key: AppKeys.autoBackupScreen,
      appBar: AppBar(title: const Text('自動バックアップ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (hasBackupNow)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SemanticHelper.interactive(
                      testId: 'auto_backup_now',
                      label: '今すぐバックアップする',
                      child: FilledButton.icon(
                        key: AppKeys.autoBackupNow,
                        onPressed: _busy ? null : _onBackupNowPressed,
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('今すぐバックアップ'),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _presenter.retentionLabel(_rows.length),
                    key: AppKeys.autoBackupRetention,
                  ),
                ),
                if (_rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'バックアップはまだありません',
                        key: AppKeys.autoBackupEmpty,
                      ),
                    ),
                  )
                else
                  for (final row in _rows)
                    ListTile(
                      key: AppKeys.autoBackupRow(row.entry.fileName),
                      title: Text(row.displayLabel),
                      subtitle: Text(row.dateLabel),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasRestorer)
                            SemanticHelper.interactive(
                              testId:
                                  'auto_backup_restore_${row.entry.fileName}',
                              label: '${row.sizeLabel}の世代を復元する',
                              child: IconButton(
                                key: AppKeys.autoBackupRestore(
                                  row.entry.fileName,
                                ),
                                tooltip: '復元',
                                icon: const Icon(Icons.restore),
                                onPressed:
                                    _busy ? null : () => _onRestorePressed(row),
                              ),
                            ),
                          if (hasSharer)
                            SemanticHelper.interactive(
                              testId:
                                  'auto_backup_share_${row.entry.fileName}',
                              label: '${row.sizeLabel}の世代を共有する',
                              child: IconButton(
                                key:
                                    AppKeys.autoBackupShare(row.entry.fileName),
                                tooltip: '共有',
                                icon: const Icon(Icons.ios_share),
                                onPressed: () => _onSharePressed(row),
                              ),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}
