import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/report/domain/period_report.dart';
import 'package:book_review_app/features/report/domain/period_report_service.dart';
import 'package:book_review_app/features/report/domain/report_period.dart';

/// 期間レポート画面のデータソース抽象（テスト注入用）。
abstract class PeriodReportDataSource {
  Future<List<Book>> getBooks();

  Future<List<Review>> getAllReviews();

  Future<List<ReadingSession>> getSessions();
}

/// 既存 Hive リポジトリ3件を合成した [PeriodReportDataSource] 実装。
class _HivePeriodReportDataSource implements PeriodReportDataSource {
  final HiveBookRepository _bookRepository = HiveBookRepository();
  final HiveChallengeRepository _challengeRepository =
      HiveChallengeRepository();
  final HiveReadingSessionRepository _sessionRepository =
      const HiveReadingSessionRepository();
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

/// 期間レポート画面。
///
/// 週次（月曜始まり）/月次の集計期間を選び、読了冊数・総読書時間・
/// 読了本・お気に入りレビューを俯瞰する。
class PeriodReportScreen extends StatefulWidget {
  /// データソース（テスト注入用）。nullなら Hive 実装。
  final PeriodReportDataSource? dataSource;

  /// 基準日時（テストの決定論化用）。未指定なら実時計。
  final DateTime Function()? now;

  const PeriodReportScreen({super.key, this.dataSource, this.now});

  @override
  State<PeriodReportScreen> createState() => _PeriodReportScreenState();
}

class _PeriodReportScreenState extends State<PeriodReportScreen> {
  final PeriodReportService _service = const PeriodReportService();
  PeriodReportDataSource? _source;
  ReportRange _range = ReportRange.week;
  DateTime _now = DateTime.now();
  DateTime _reference = DateTime.now();
  bool _isLoading = true;
  PeriodReport? _report;

  @override
  void initState() {
    super.initState();
    _now = widget.now?.call() ?? DateTime.now();
    _reference = _now;
    _source = widget.dataSource ?? _HivePeriodReportDataSource();
    _reload();
  }

  ReportPeriod get _period => _range == ReportRange.week
      ? ReportPeriod.weekOf(_reference)
      : ReportPeriod.monthOf(_reference);

  Future<void> _reload() async {
    final period = _period;
    final source = _source!;
    final books = await source.getBooks();
    final reviews = await source.getAllReviews();
    final sessions = await source.getSessions();
    if (!mounted) return;
    setState(() {
      _report = _service.build(
        books: books,
        reviews: reviews,
        sessions: sessions,
        period: period,
        now: _now,
      );
      _isLoading = false;
    });
  }

  void _setRange(ReportRange range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _isLoading = true;
      _report = null;
    });
    _reload();
  }

  void _shift(int direction) {
    setState(() {
      _reference =
          direction < 0 ? _period.previous().start : _period.next().start;
      _isLoading = true;
      _report = null;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.periodReportScreen,
      appBar: AppBar(title: const Text('期間レポート')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ToggleButtons(
                isSelected: [
                  _range == ReportRange.week,
                  _range == ReportRange.month,
                ],
                onPressed: (index) => _setRange(
                  index == 0 ? ReportRange.week : ReportRange.month,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      ReportRange.week.label,
                      key: AppKeys.periodReportRangeWeek,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      ReportRange.month.label,
                      key: AppKeys.periodReportRangeMonth,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: AppKeys.periodReportPrevButton,
                icon: const Icon(Icons.chevron_left),
                tooltip: '前の期間',
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Text(
                  _period.label,
                  key: AppKeys.periodReportPeriodLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                key: AppKeys.periodReportNextButton,
                icon: const Icon(Icons.chevron_right),
                tooltip: '次の期間',
                onPressed: () => _shift(1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(key: AppKeys.periodReportLoading),
      );
    }
    final report = _report;
    if (report == null) {
      return const Center(child: Text('レポートを読み込めませんでした。'));
    }
    if (report.isEmpty) {
      return const Center(
        child: Text(
          'この期間の読書記録はありません',
          key: AppKeys.periodReportEmpty,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('読了冊数')),
                    Text(
                      '${report.finishedCount} 冊',
                      key: AppKeys.periodReportFinishedCount,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('総読書時間')),
                    Text(
                      report.totalMinutesLabel,
                      key: AppKeys.periodReportTotalMinutes,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '読了した本（${report.finishedBooks.length}冊）',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        for (final book in report.finishedBooks)
          ListTile(
            key: Key('period_report_book_${book.id}'),
            title: Text(book.title),
            subtitle: Text(book.author),
            leading: const Icon(Icons.menu_book_outlined),
          ),
        const SizedBox(height: 12),
        Text(
          'お気に入りのレビュー',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        for (var i = 0; i < report.favoriteReviews.length; i++)
          ListTile(
            key: AppKeys.periodReportFavoriteReview(i),
            title: Text(report.favoriteReviews[i].text),
            subtitle: Text('★${report.favoriteReviews[i].rating}'),
            leading: const Icon(Icons.favorite_outline),
          ),
      ],
    );
  }
}
