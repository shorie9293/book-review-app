/// 読書シェアカード画面。
library;

import 'package:flutter/material.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/share/domain/share_card_data.dart';
import 'package:book_review_app/features/share/domain/share_card_service.dart';
import 'package:book_review_app/features/share/presentation/share_card_capture.dart';
import 'package:book_review_app/features/share/presentation/share_card_exporter.dart';
import 'package:book_review_app/features/reading/domain/reading_stats.dart'
    as reading_stats;
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

/// 読書シェアカード画面。
///
/// 統計データからシェアカードを組み立て、テキスト/画像で共有する。
/// データ源・基準日・キャプチャ・共有はすべて注入可能（テスト用）。
class ShareCardScreen extends StatefulWidget {
  /// 統計データ源（テスト注入用）。nullの構成は本番想定外だが未使用データ。
  final StatsDataSource? dataSource;

  /// 統計基準日（テストの決定論化用）。未指定なら実時計。
  final DateTime Function()? now;

  /// 既製データの上書き注入（テスト用）。非nullならこれを最優先で表示。
  final ShareCardData? dataOverride;

  /// カード画像キャプチャ。nullなら画像共有ボタンを無効化する。
  final ShareCardCapture? capture;

  /// 共有エクスポーター。
  final ShareCardExporter? exporter;

  const ShareCardScreen({
    super.key,
    this.dataSource,
    this.now,
    this.dataOverride,
    this.capture,
    this.exporter,
  });

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  /// widget の値を late final で捕まえない（実測禍津）。getter で都度参照する。
  StatsDataSource? get _dataSource => widget.dataSource;

  ShareCardData? _data;
  bool _isLoading = true;
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final override = widget.dataOverride;
    if (override != null) {
      setState(() {
        _data = override;
        _isLoading = false;
      });
      return;
    }
    final source = _dataSource;
    if (source == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final books = await source.getBooks();
      final reviews = await source.getAllReviews();
      final now = widget.now ?? DateTime.now;
      // StatsDataSource は読書セッションを提供しないため、
      // 読書時間・活動日数は空統計（0分/0日）を渡す。
      final data = ShareCardService.build(
        books: books,
        reviews: reviews,
        stats: const reading_stats.ReadingStats.empty(),
        now: now(),
      );
      setState(() => _data = data);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareText() async {
    final data = _data;
    if (data == null) return;
    final exporter = widget.exporter ?? const SharePlusExporter();
    await exporter.share(image: null, text: ShareCardService.shareText(data));
  }

  Future<void> _shareImage() async {
    final data = _data;
    if (data == null) return;
    final capture = widget.capture;
    if (capture == null) return;
    final exporter = widget.exporter ?? const SharePlusExporter();
    final bytes = await capture.capture(_previewKey);
    await exporter.share(
      image: bytes,
      text: ShareCardService.shareText(data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      key: AppKeys.shareCardScreen,
      appBar: AppBar(title: const Text('読書シェアカード')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? const Center(child: Text('シェアカードを作成できませんでした。'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _buildPreviewCard(data)),
                      const Spacer(),
                      Semantics(
                        button: true,
                        child: ElevatedButton(
                          key: AppKeys.shareCardTextShareButton,
                          onPressed: _shareText,
                          child: const Text('テキストとして共有'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        button: true,
                        child: ElevatedButton(
                          key: AppKeys.shareCardImageShareButton,
                          onPressed:
                              widget.capture == null ? null : _shareImage,
                          child: const Text('画像として共有'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPreviewCard(ShareCardData data) {
    final fav = data.favoriteReview;
    final generated = data.generatedAt;
    final month = generated.month.toString().padLeft(2, '0');
    final day = generated.day.toString().padLeft(2, '0');
    return RepaintBoundary(
      key: _previewKey,
      child: Container(
        key: AppKeys.shareCardPreview,
        width: 360,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📚 読書の歩み',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(data.completedLabel),
            Text('読書時間: ${data.minutesLabel}'),
            Text(data.unreadLabel),
            if (fav != null) ...[
              const SizedBox(height: 8),
              Text('⭐' * fav.rating),
              Text('「${fav.excerpt}」'),
              Text('〈${fav.bookTitle}〉'),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${generated.year}/$month/$day'),
            ),
          ],
        ),
      ),
    );
  }
}
