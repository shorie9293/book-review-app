import 'package:flutter/material.dart';
import 'package:book_review_app/features/import/data/import_history_repository.dart';
import 'package:book_review_app/features/import/domain/import_history_entry.dart';
import 'package:book_review_app/features/import/domain/import_history_service.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 一括インポートの実行履歴を一覧する画面。
///
/// 集計・並べ替え・絞り込みはすべて [ImportHistoryService] に委ね、
/// 本画面は表示と選択状態のみを持つ。
class ImportHistoryScreen extends StatefulWidget {
  final ImportHistoryRepository repository;

  /// 現在時刻の取得関数（試練で固定値を注入可能）
  final DateTime Function()? clock;

  const ImportHistoryScreen({
    super.key,
    required this.repository,
    this.clock,
  });

  @override
  State<ImportHistoryScreen> createState() => _ImportHistoryScreenState();
}

class _ImportHistoryScreenState extends State<ImportHistoryScreen> {
  List<ImportHistoryEntry> _entries = const [];
  String _selectedMode = ImportHistoryService.allModesLabel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<ImportHistoryEntry> loaded;
    try {
      loaded = await widget.repository.load();
    } catch (_) {
      loaded = const [];
    }
    if (!mounted) return;
    setState(() {
      _entries = ImportHistoryService.sortNewestFirst(loaded);
      _selectedMode = ImportHistoryService.allModesLabel;
      _loading = false;
    });
  }

  /// 履歴に出現したモード（初出順・重複なし）
  List<String> get _availableModes {
    final modes = <String>[];
    for (final entry in _entries) {
      if (!modes.contains(entry.mode)) modes.add(entry.mode);
    }
    return modes;
  }

  void _showDetail(ImportHistoryEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('import_history_detail_dialog'),
        title: const Text('取込の詳細'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ImportHistoryService.formatTimestamp(entry.importedAt)),
              const SizedBox(height: 4),
              Text('モード: ${entry.mode}'),
              Text('結果: ${entry.outcomeLabel}'),
              const SizedBox(height: 4),
              Text(entry.summaryLabel),
              if (entry.sampleIsbns.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('代表ISBN',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                for (final isbn in entry.sampleIsbns)
                  Text(isbn, key: Key('import_history_detail_isbn_$isbn')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('import_history_detail_close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = ImportHistoryService.summarize(_entries);
    final visible = ImportHistoryService.sortNewestFirst(
      ImportHistoryService.filterByMode(_entries, _selectedMode),
    );

    return Scaffold(
      key: const Key('screen_import_history'),
      appBar: AppBar(
        title: const Text('取込履歴'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                key: Key('import_history_loading'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(summary),
                const SizedBox(height: 12),
                _buildFilterChips(),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  Padding(
                    key: const Key('import_history_empty'),
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      '取込履歴はまだありません',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                else
                  for (final entry in visible) _buildRow(entry),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(ImportHistorySummary summary) {
    Widget cell(String keySuffix, String label, int value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                '$value',
                key: Key('import_history_summary_$keySuffix'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        );

    return SemanticHelper.container(
      testId: 'import_history_summary',
      label: '取込履歴の集計',
      child: Card(
        key: const Key('import_history_summary_card'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('集計', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [cell('runs', '取込回数', summary.runs)]),
              const SizedBox(height: 8),
              Row(children: [
                cell('added', '追加計', summary.addedCount),
                cell('skipped', '登録済計', summary.skippedCount),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                cell('not_found', '書誌なし計', summary.notFoundCount),
                cell('failed', '失敗計', summary.failedCount),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        _chip(
          keyId: 'import_history_filter_all',
          label: ImportHistoryService.allModesLabel,
          selected: _selectedMode == ImportHistoryService.allModesLabel,
        ),
        for (final mode in _availableModes)
          _chip(
            keyId: 'import_history_filter_$mode',
            label: mode,
            selected: _selectedMode == mode,
          ),
      ],
    );
  }

  Widget _chip({
    required String keyId,
    required String label,
    required bool selected,
  }) {
    return ChoiceChip(
      key: Key(keyId),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedMode = label),
    );
  }

  Widget _buildRow(ImportHistoryEntry entry) {
    return Card(
      key: Key('import_history_row_${entry.id}'),
      child: ListTile(
        onTap: () => _showDetail(entry),
        title: Text(ImportHistoryService.formatTimestamp(entry.importedAt)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.mode} / ${entry.summaryLabel}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              entry.outcomeLabel,
              key: Key('import_history_outcome_${entry.id}'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
