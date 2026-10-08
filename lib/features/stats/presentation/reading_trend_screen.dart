import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/domain/reading_trend.dart';
import 'package:book_review_app/features/stats/presentation/widgets/reading_trend_charts.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 読書統計グラフ画面が依存するデータソース（テスト注入用の抽象化）。
abstract class TrendDataSource {
  Future<List<Book>> getBooks();
  Future<List<Review>> getAllReviews();
  Future<List<ReadingSession>> getSessions();
}

/// 既存 Hive リポジトリ3件を合成した [TrendDataSource] 実装。
class _HiveTrendDataSource implements TrendDataSource {
  final HiveBookRepository _bookRepository = HiveBookRepository();
  final HiveChallengeRepository _challengeRepository =
      HiveChallengeRepository();
  final HiveReadingSessionRepository _sessionRepository =
      HiveReadingSessionRepository();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _bookRepository.init();
    await _challengeRepository.init();
    await _sessionRepository.init();
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

  @override
  Future<List<ReadingSession>> getSessions() async {
    await _ensureInit();
    return _sessionRepository.loadAll();
  }
}

/// 読書統計グラフ画面。
///
/// 月別読了冊数（棒）・月別読書時間（折れ線）・ジャンル分布（円）を俯瞰する。
/// 集計ロジックは [ReadingTrendService] が担い、この画面は表示のみを行う。
class ReadingTrendScreen extends StatefulWidget {
  /// データソース（テスト注入用）。未指定なら Hive 3リポジトリの合成実装。
  final TrendDataSource? dataSource;

  /// 統計基準日（テストの決定論化用）。未指定なら実時計。
  final DateTime Function()? now;

  const ReadingTrendScreen({super.key, this.dataSource, this.now});

  @override
  State<ReadingTrendScreen> createState() => _ReadingTrendScreenState();
}

class _ReadingTrendScreenState extends State<ReadingTrendScreen> {
  late final TrendDataSource _source =
      widget.dataSource ?? _HiveTrendDataSource();
  bool _loading = true;
  bool _failed = false;
  ReadingTrend? _trend;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait(<Future<List<Object>>>[
        _source.getBooks(),
        _source.getAllReviews(),
        _source.getSessions(),
      ]);
      final trend = const ReadingTrendService().compute(
        books: results[0] as List<Book>,
        reviews: results[1] as List<Review>,
        sessions: results[2] as List<ReadingSession>,
        now: widget.now?.call(),
      );
      if (!mounted) return;
      setState(() {
        _trend = trend;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.readingTrendScreen,
      appBar: AppBar(title: const Text('読書グラフ')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        key: AppKeys.readingTrendLoading,
        child: CircularProgressIndicator(),
      );
    }
    if (_failed) {
      return const Center(child: Text('読み込みに失敗しました。'));
    }

    final trend = _trend;
    if (trend == null || trend.isEmpty) {
      return const Center(
        key: AppKeys.readingTrendEmpty,
        child: Text('この年の読書記録がありません'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SemanticHelper.container(
            testId: 'reading_trend_summary',
            label: '${trend.year}年の読書: 読了${trend.totalFinished}冊',
            child: _buildSummaryCard(trend),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '月別の読了冊数',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  MonthlyFinishedBarChart(
                    monthlyFinished: trend.monthlyFinished,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '月別の読書時間（分）',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  MonthlyMinutesLineChart(monthlyMinutes: trend.monthlyMinutes),
                ],
              ),
            ),
          ),
          if (trend.genreCounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ジャンル分布',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    GenreDistributionPieChart(
                      genreCounts: trend.genreCounts,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ReadingTrend trend) {
    final busiest = trend.busiestFinishedMonth;
    return Card(
      key: AppKeys.readingTrendSummary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${trend.year}年の読書',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '読了 ${trend.totalFinished} 冊',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('総読書時間 ${trend.totalMinutesLabel}'),
            if (busiest != null) Text('最多読了月: $busiest月'),
          ],
        ),
      ),
    );
  }
}