import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:book_review_app/features/backup/data/backup_csv_sharer.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/backup/domain/restore_preview.dart';
import 'package:book_review_app/features/backup/presentation/backup_keys.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/data/book_deletion_service.dart';
import 'package:book_review_app/features/bookshelf/domain/book_deletion.dart';
import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';
import 'package:book_review_app/features/crossapp/presentation/cross_app_link_keys.dart';
import 'package:book_review_app/features/crossapp/presentation/cross_app_link_screen.dart';

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

  /// クロスアプリ連携の userId 保管庫（未指定なら連携画面への導線を出さない）
  final CrossAppLinkRepository? crossAppLinkRepository;

  /// クロスアプリ連携の送信済みイベント記録（未指定なら件数行を出さない）
  final RewardExportLogRepository? crossAppRewardLogRepository;

  /// 蔵書 CSV の共有口（未指定なら「CSVを共有」ボタンを出さない）
  final BackupCsvSharer? csvSharer;

  /// 全レビュー読み出し口（未指定なら「保存先を失ったデータ」節を出さない）
  final Future<List<Review>> Function()? allReviewsLoader;

  /// 孤児データの刈り取りサービス（未指定なら同節を出さない）
  final BookDeletionService? orphanCleanupService;

  const BackupScreen({
    super.key,
    required this.repository,
    this.service = const BackupService(),
    this.clipboardWriter = _defaultClipboardWriter,
    this.crossAppLinkRepository,
    this.crossAppRewardLogRepository,
    this.csvSharer,
    this.allReviewsLoader,
    this.orphanCleanupService,
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

  /// 保存先を失ったデータ（null は未検出・検出失敗＝節を出さない）
  OrphanData? _orphans;

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
      _orphans = null;
    });
    try {
      final bundle = await widget.repository.collect();
      final orphans = await _detectOrphans(bundle);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _orphans = orphans;
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

  /// 全レビューを読み、蔵書から参照されていないデータを検出する。
  ///
  /// [BackupScreen.allReviewsLoader] が未指定・失敗時は null（節を出さない）。
  Future<OrphanData?> _detectOrphans(BackupBundle bundle) async {
    final loader = widget.allReviewsLoader;
    if (loader == null) return null;
    try {
      final reviews = await loader();
      return OrphanData.detect(
        books: bundle.books,
        reviews: reviews,
        notes: bundle.notes,
      );
    } catch (_) {
      return null;
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

  /// 蔵書一覧をCSVファイルにして共有シートへ渡す。
  ///
  /// 共有する CSV は BOM 無し（BOM は [BackupCsvSharer] 実装が付ける）。
  Future<void> _shareCsv() async {
    final sharer = widget.csvSharer;
    final bundle = _bundle;
    if (sharer == null || bundle == null) return;
    final csv = BackupService.exportBooksCsv(bundle.books);
    await sharer.share(
      csv: csv,
      fileName: backupCsvFileName(DateTime.now()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('蔵書CSVを共有しました')),
    );
  }

  /// 復元前プレビューを組み立てる。取得失敗時は null（従来表示のまま）。
  Future<RestorePreview?> _buildRestorePreview(BackupBundle incoming) async {
    try {
      final existing = await widget.repository.collect();
      return RestorePreview.tryBuild(incoming: incoming, existing: existing);
    } catch (_) {
      // 現状を採取できないときは内訳を出さない（復元導線は従来どおり通す）。
      return null;
    }
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

    // 復元前プレビュー（取得に失敗しても従来表示のまま復元導線は止めない）
    final preview = await _buildRestorePreview(parsed);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('復元の確認'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '蔵書 ${parsed.books.length}件 / レビュー ${parsed.reviews.length}件 / '
                'メモ ${parsed.notes.length}件 を復元します。\n'
                '既存のデータは上書きされません。よろしいですか？',
              ),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.summary,
                        key: BackupKeys.restorePreviewSummary,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          preview.breakdown,
                          key: BackupKeys.restorePreviewBreakdown,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(preview.message),
                      ),
                      if (preview.samplesText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            preview.samplesText!,
                            key: BackupKeys.restorePreviewSamples,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
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

    final children = <Widget>[];
    if (_loadError != null) {
      children.addAll([
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
      ]);
    } else {
      final bundle = _bundle;
      if (bundle == null) {
        children.add(const Center(child: Text('データがありません')));
      } else {
        children.addAll([
          _buildSummaryCard(bundle),
          const SizedBox(height: 16),
          _buildExportSection(),
          const Divider(height: 32),
          _buildRestoreSection(),
        ]);
      }
    }

    final crossAppLinkRepository = widget.crossAppLinkRepository;
    if (crossAppLinkRepository != null) {
      children.addAll([
        const Divider(height: 32),
        _buildCrossAppLinkSection(crossAppLinkRepository),
      ]);
    }

    final orphans = _orphans;
    final orphanCleanupService = widget.orphanCleanupService;
    if (orphans != null &&
        !orphans.isEmpty &&
        orphanCleanupService != null) {
      children.addAll([
        const Divider(height: 32),
        _buildOrphanSection(orphans, orphanCleanupService),
      ]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// クロスアプリ連携画面への導線。
  Widget _buildCrossAppLinkSection(CrossAppLinkRepository linkRepository) {
    return ListTile(
      key: CrossAppLinkKeys.entry,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link),
      title: const Text('クロスアプリ連携'),
      subtitle: const Text('読み終えた本を rpg-task のコイン・EXP・称号に反映する'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openCrossAppLink(linkRepository),
    );
  }

  /// クロスアプリ連携画面を開く。
  Future<void> _openCrossAppLink(CrossAppLinkRepository linkRepository) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CrossAppLinkScreen(
          linkRepository: linkRepository,
          logRepository: widget.crossAppRewardLogRepository,
        ),
      ),
    );
  }

  /// 保存先を失ったデータ（孤児レビュー・メモ）の節。
  ///
  /// 表示のみで、自動削除は行わない。ユーザーが「刈り取る」を押した時だけ動く。
  Widget _buildOrphanSection(
    OrphanData orphans,
    BookDeletionService service,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('保存先を失ったデータ', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(orphans.summaryLabel),
        const SizedBox(height: 4),
        const Text('本棚から消えた本に属するデータです。バックアップには含まれません。'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          key: const Key('orphan_cleanup_button'),
          onPressed: () => _confirmOrphanCleanup(orphans, service),
          icon: const Icon(Icons.delete_sweep),
          label: const Text('刈り取る'),
        ),
      ],
    );
  }

  /// 確認ダイアログを経て孤児データを刈り取る。
  Future<void> _confirmOrphanCleanup(
    OrphanData orphans,
    BookDeletionService service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存先を失ったデータの削除'),
        content: Text(
          '${orphans.summaryLabel} を削除します。元に戻せません。よろしいですか？',
        ),
        actions: [
          TextButton(
            key: const Key('orphan_cleanup_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: const Key('orphan_cleanup_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final report = await service.deleteOrphans(orphans);
    if (!mounted) return;
    final deleted = report.deletedReviews + report.deletedNotes;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('刈り取り完了: 成功 $deleted件 / 失敗 ${report.failures.length}件'),
      ),
    );
    await _reload();
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
        if (widget.csvSharer != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: BackupKeys.csvShareButton,
            onPressed: _bundle == null ? null : _shareCsv,
            icon: const Icon(Icons.share),
            label: const Text('CSVを共有'),
          ),
        ],
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
