import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/backup/presentation/backup_keys.dart';

/// エクスポート／バックアップ画面。
///
/// 蔵書・レビュー・読書メモを JSON へ書き出し（コピー）、
/// 貼り付けた JSON を既存データへ安全に足し込む（既存優先・上書きしない）。
class BackupScreen extends StatefulWidget {
  /// バックアップ対象のリポジトリ（collect / restore）
  final BackupRepository repository;

  /// ドメインサービス（既定は [BackupService] の既定実装）
  final BackupService service;

  /// クリップボード書き込み口（試練ではインメモリ実装を注入する）
  final Future<void> Function(String value) clipboardWriter;

  const BackupScreen({
    super.key,
    required this.repository,
    this.service = const BackupService(),
    this.clipboardWriter = _defaultClipboardWriter,
  });

  static Future<void> _defaultClipboardWriter(String value) {
    return Clipboard.setData(ClipboardData(text: value));
  }

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController _importController = TextEditingController();

  /// 画面ロード状態（loading / loaded / error）
  bool _isLoading = true;
  String? _loadError;
  BackupBundle? _bundle;

  /// エクスポート節・復元節の状態
  String? _exportedJson;
  String? _restoreError;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  /// 現在のデータを採取してサマリーを更新する。
  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final bundle = await widget.repository.collect();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'データの読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  /// 「エクスポート」ボタン：整形JSONを生成してプレビューへ出す。
  void _exportJson() {
    final bundle = _bundle;
    if (bundle == null) return;
    setState(() {
      _exportedJson = widget.service.exportJson(bundle);
    });
  }

  /// 整形JSONをクリップボードへ写す。
  Future<void> _copyJson() async {
    final json = _exportedJson;
    if (json == null) return;
    await widget.clipboardWriter(json);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('バックアップJSONをクリップボードにコピーしました')),
    );
  }

  /// 蔵書一覧をCSVにしてクリップボードへ写す。
  Future<void> _copyCsv() async {
    final bundle = _bundle;
    if (bundle == null) return;
    final csv = BackupService.exportBooksCsv(bundle.books);
    await widget.clipboardWriter(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('蔵書CSVをクリップボードにコピーしました')),
    );
  }

  /// 「復元」ボタン：JSONを検証して確認ダイアログへ進む。
  Future<void> _startRestore() async {
    setState(() {
      _restoreError = null;
    });
    final BackupBundle parsed;
    try {
      parsed = widget.service.parse(_importController.text);
    } on FormatException catch (e) {
      setState(() {
        _restoreError = 'JSONの形式が正しくありません: ${e.message}';
      });
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('復元の確認'),
        content: Text(
          '蔵書 ${parsed.books.length}件 / レビュー ${parsed.reviews.length}件 / '
          'メモ ${parsed.notes.length}件 を復元します。\n'
          '既存のデータは上書きされません。よろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: BackupKeys.confirmRestoreButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      _isRestoring = true;
    });
    try {
      final result = await widget.repository.restore(parsed);
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _importController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '復元完了: 追加 ${result.totalAdded}件 / スキップ ${result.totalSkipped}件',
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _restoreError = '復元中にエラーが発生しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: BackupKeys.screen,
      appBar: AppBar(title: const Text('エクスポート / バックアップ')),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _loadError!,
              key: BackupKeys.errorText,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _reload,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    final bundle = _bundle;
    if (bundle == null) {
      return const Center(child: Text('データがありません'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(bundle),
          const SizedBox(height: 16),
          _buildExportSection(),
          const Divider(height: 32),
          _buildRestoreSection(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BackupBundle bundle) {
    final summary = BackupSummary.of(bundle);
    return Card(
      key: BackupKeys.summaryCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('バックアップ対象', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(summary.label),
            const SizedBox(height: 4),
            Text('合計 ${summary.total}件', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('エクスポート', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: BackupKeys.exportButton,
                onPressed: _exportJson,
                icon: const Icon(Icons.upload_file),
                label: const Text('エクスポート'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: BackupKeys.copyButton,
              tooltip: 'JSONをコピー',
              onPressed: _exportedJson == null ? null : _copyJson,
              icon: const Icon(Icons.copy),
            ),
            IconButton(
              key: BackupKeys.csvExportButton,
              tooltip: '蔵書CSVをコピー',
              onPressed: _bundle == null ? null : _copyCsv,
              icon: const Icon(Icons.table_view),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_exportedJson != null)
          SizedBox(
            height: 220,
            child: Container(
              key: BackupKeys.jsonPreview,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  _exportedJson!,
                  key: BackupKeys.jsonPreview,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRestoreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('復元', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('貼り付けたJSONを既存データへ足し込みます（既存のデータは上書きしません）。'),
        const SizedBox(height: 8),
        TextField(
          key: BackupKeys.importField,
          controller: _importController,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'バックアップJSONを貼り付け',
            border: OutlineInputBorder(),
          ),
        ),
        if (_restoreError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _restoreError!,
              key: BackupKeys.errorText,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          key: BackupKeys.restoreButton,
          onPressed: _isRestoring ? null : _startRestore,
          icon: const Icon(Icons.restore),
          label: const Text('復元'),
        ),
      ],
    );
  }
}
