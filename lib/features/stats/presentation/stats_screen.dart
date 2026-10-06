import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:book_review_app/features/stats/domain/reading_stats_service.dart';
import 'package:book_review_app/features/stats/domain/year_comparison.dart';
import 'package:book_review_app/features/stats/presentation/finish_forecast_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/finish_forecast_view_model.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 既存 Hive リポジトリ2件を合成した [StatsDataSource] 実装。
class _HiveStatsDataSource implements StatsDataSource {
  final HiveBookRepository _bookRepository = HiveBookRepository();
  final HiveChallengeRepository _challengeRepository =
      HiveChallengeRepository();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _bookRepository.init();
    await _challengeRepository.init();
    _initialized = true;
  }

  @override
  Future<List<Book>> getBooks() async {
    await _ensureInit();
    return _bookRepository.getBooks();
  }

  @override
  Future<List<Review>> getAllReviews() async {
    await _ensureInit();
    return _challengeRepository.getAllReviews();
  }
}

/// 読書統計ダッシュボード画面。
///
/// 月別読了冊数・著者別読了分布・平均評価・読了ペースを俯瞰する。
class StatsScreen extends StatefulWidget {
  final StatsDataSource? dataSource;

  /// 読了予測画面に渡すデータソース（テスト注入用）。
  final FinishForecastDataSource? forecastDataSource;

  /// 統計基準日（テストの決定論化用）。未指定なら実時計。
  final DateTime Function()? now;

  const StatsScreen({
    super.key,
    this.dataSource,
    this.forecastDataSource,
    this.now,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final StatsViewModel _viewModel = StatsViewModel(now: widget.now);
  StatsDataSource? _source;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _source = widget.dataSource ?? _HiveStatsDataSource();
    _viewModel.addListener(_handleViewModelChange);
    await _viewModel.load(_source!);
  }

  void _handleViewModelChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChange);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_stats'),
      appBar: AppBar(
        title: const Text('読書統計'),
        actions: [
          IconButton(
            key: AppKeys.finishForecastOpenButton,
            icon: const Icon(Icons.insights),
            tooltip: '読了予測',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FinishForecastScreen(
                    dataSource: widget.forecastDataSource,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final error = _viewModel.error;
    if (error != null) {
      return const Center(child: Text('統計の読み込みに失敗しました。'));
    }

    final stats = _viewModel.stats;
    final comparison = _viewModel.comparison;
    if (stats == null || stats.totalFinished == 0) {
      return const Center(child: Text('まだ読了データがありません。'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SemanticHelper.container(
            testId: 'stats_summary',
            label: '${stats.year}年の読書統計: 読了${stats.totalFinished}冊',
            child: _buildSummaryCard(context, stats),
          ),
          const SizedBox(height: 16),
          SemanticHelper.container(
            testId: 'stats_monthly',
            label: '月別の読了冊数',
            child: _buildMonthlyCard(context, stats),
          ),
          const SizedBox(height: 16),
          SemanticHelper.container(
            testId: 'stats_author',
            label: '著者別の読了分布',
            child: _buildAuthorCard(context, stats),
          ),
          if (comparison != null) ...[
            const SizedBox(height: 16),
            SemanticHelper.container(
              testId: 'stats_year_comparison',
              label: '前年比: ${comparison.headLabel}',
              child: _buildComparisonCard(context, comparison),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
    BuildContext context,
    YearComparison comparison,
  ) {
    return Card(
      key: AppKeys.statsYearComparison,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 前年比 ${comparison.headLabel}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!comparison.hasPreviousData)
              const Text('前年のデータがありません')
            else ...[
              Row(
                children: [
                  const Expanded(child: Text('読了冊数')),
                  Text(
                    comparison.finishedLabel,
                    key: AppKeys.statsComparisonFinished,
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('読了ページ数')),
                  Text(
                    comparison.pagesLabel,
                    key: AppKeys.statsComparisonPages,
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('著者数')),
                  Text(
                    comparison.authorLabel,
                    key: AppKeys.statsComparisonAuthors,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, ReadingStats stats) {
    final rating = stats.averageRating;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 ${stats.year}年の読書',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '読了 ${stats.totalFinished} 円'
              .replaceFirst('円', '冊'),
              key: const Key('stats_total'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('月平均 ${stats.pacePerMonth.toStringAsFixed(1)} 冊'),
            if (rating != null)
              Text('レビュー平均評価 ${rating.toStringAsFixed(1)}'),
            if (stats.topAuthor != null) Text('最多著者: ${stats.topAuthor}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCard(BuildContext context, ReadingStats stats) {
    final maxCount =
        stats.monthlyCounts.reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '月別の読了冊数',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              key: const Key('stats_monthly_bar'),
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 12; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (stats.monthlyCounts[i] > 0)
                              Text(
                                '${stats.monthlyCounts[i]}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            const SizedBox(height: 2),
                            Container(
                              height: maxCount == 0
                                  ? 2.0
                                  : 60.0 * stats.monthlyCounts[i] / maxCount,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorCard(BuildContext context, ReadingStats stats) {
    final entries = stats.authorCounts.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '著者別の読了分布',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final entry in entries.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Text('${entry.value} 冊'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
