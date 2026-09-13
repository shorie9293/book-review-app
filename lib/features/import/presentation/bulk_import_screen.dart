import 'package:flutter/material.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/import/domain/bulk_import_parser.dart';
import 'package:book_review_app/features/import/domain/bulk_import_service.dart';
import 'package:book_review_app/features/import/presentation/viewmodel/bulk_import_view_model.dart';

/// 蔵書の一括インポート画面。
///
/// ISBN リストの貼り付け、または CSV テキストの貼り付けから蔵書をまとめて登録する。
/// 解析（プレビュー）→ 取り込み（実行）の2段階で操作する。
class BulkImportScreen extends StatefulWidget {
  final BookRepository repository;
  final BookSearchService searchService;

  /// 取り込み完了時に呼ばれる（本棚の再読み込みなどに使用）。
  final VoidCallback? onImported;

  const BulkImportScreen({
    super.key,
    required this.repository,
    required this.searchService,
    this.onImported,
  });

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final TextEditingController _controller = TextEditingController();
  final BulkImportViewModel _viewModel = BulkImportViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _runImport() async {
    await _viewModel.runImport(
      repository: widget.repository,
      searchService: widget.searchService,
    );
    if (!mounted) return;
    final report = _viewModel.report;
    if (report != null) {
      widget.onImported?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${report.addedCount}冊を本棚に追加しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _viewModel.preview;
    final report = _viewModel.report;

    return Scaffold(
      key: const Key('screen_bulk_import'),
      appBar: AppBar(
        title: const Text('蔵書の一括インポート'),
        actions: [
          IconButton(
            key: const Key('bulk_import_reset_button'),
            icon: const Icon(Icons.refresh),
            tooltip: 'リセット',
            onPressed: () {
              _controller.clear();
              _viewModel.reset();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<BulkImportMode>(
            key: const Key('bulk_import_mode_selector'),
            segments: [
              for (final mode in BulkImportMode.values)
                ButtonSegment<BulkImportMode>(
                  value: mode,
                  label: Text(mode.label),
                  icon: Icon(mode == BulkImportMode.isbnList
                      ? Icons.format_list_numbered
                      : Icons.table_chart),
                ),
            ],
            selected: {_viewModel.mode},
            onSelectionChanged: (selection) => _viewModel.setMode(selection.first),
          ),
          const SizedBox(height: 12),
          Text(
            _viewModel.mode == BulkImportMode.isbnList
                ? 'ISBNを1行に1冊ずつ貼り付けてください（ハイフン可・カンマ区切りも可）'
                : 'CSVを貼り付けてください（列: isbn,title,author / ヘッダ行は任意）',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('bulk_import_text_field'),
            controller: _controller,
            minLines: 6,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '9784774189079\n9784123456784',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('bulk_import_parse_button'),
                  onPressed: _viewModel.isImporting ? null : () => _viewModel.parse(_controller.text),
                  icon: const Icon(Icons.search),
                  label: const Text('解析'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('bulk_import_run_button'),
                  onPressed: (preview != null && preview.hasImportable && !_viewModel.isImporting)
                      ? _runImport
                      : null,
                  icon: const Icon(Icons.download_done),
                  label: const Text('取り込む'),
                ),
              ),
            ],
          ),
          if (_viewModel.isImporting) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: const Key('bulk_import_progress'),
              value: _viewModel.progressTotal == 0
                  ? null
                  : _viewModel.progressDone / _viewModel.progressTotal,
            ),
            const SizedBox(height: 4),
            Text('${_viewModel.progressDone} / ${_viewModel.progressTotal} 件処理中'),
          ],
          if (_viewModel.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _viewModel.errorMessage!,
                key: const Key('bulk_import_error'),
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          if (report != null) ...[
            const SizedBox(height: 16),
            _buildReport(report),
          ],
          if (preview != null) ...[
            const SizedBox(height: 16),
            Text(
              '解析結果: 取込可 ${preview.validCount} / 重複 ${preview.duplicateCount} / 不正 ${preview.invalidCount}',
              key: const Key('bulk_import_summary'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < preview.entries.length; i++) _buildEntryTile(preview.entries[i], i),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryTile(ImportEntry entry, int index) {
    final color = switch (entry.status) {
      ImportEntryStatus.valid => Colors.green.shade700,
      ImportEntryStatus.duplicate => Colors.orange.shade800,
      ImportEntryStatus.invalid => Colors.red.shade700,
    };
    return ListTile(
      key: Key('bulk_import_entry_$index'),
      dense: true,
      leading: Icon(
        switch (entry.status) {
          ImportEntryStatus.valid => Icons.check_circle_outline,
          ImportEntryStatus.duplicate => Icons.content_copy,
          ImportEntryStatus.invalid => Icons.error_outline,
        },
        color: color,
      ),
      title: Text(entry.isbn),
      subtitle: entry.title != null || entry.author != null
          ? Text([entry.title, entry.author].whereType<String>().join(' / '))
          : Text('${entry.line}行目'),
      trailing: Text(entry.status.label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _buildReport(BulkImportReport report) {
    return Card(
      key: const Key('bulk_import_report'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('取り込み結果', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('追加 ${report.addedCount} 冊'),
            Text('登録済（スキップ） ${report.skippedCount} 冊'),
            if (report.notFoundCount > 0) Text('書誌が見つからず ${report.notFoundCount} 冊'),
            if (report.failedCount > 0) Text('失敗 ${report.failedCount} 冊'),
          ],
        ),
      ),
    );
  }
}
