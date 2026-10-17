import 'package:flutter/material.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/badges/domain/achievement_badge.dart';
import 'package:book_review_app/features/badges/domain/achievement_badge_service.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

/// 実績バッジ画面が参照するデータソースの抽象。
///
/// Widget 試練では必ず Fake を注入する（本番実装は Hive に触れるため）。
abstract class BadgeCollectionDataSource {
  Future<List<Book>> getBooks();

  Future<List<Review>> getReviews();

  Future<List<ReadingSession>> getSessions();
}

/// 既存 Hive リポジトリ3件を合成した [BadgeCollectionDataSource] 実装。
class _HiveBadgeDataSource implements BadgeCollectionDataSource {
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
  Future<List<Review>> getReviews() async {
    await _ensureInit();
    return _challengeRepository.getAllReviews();
  }

  @override
  Future<List<ReadingSession>> getSessions() async {
    await _ensureInit();
    return _sessionRepository.loadAll();
  }
}

/// 絞込の状態。
enum _BadgeFilter { all, earned, unearned }

typedef _BadgeData = (List<Book>, List<Review>, List<ReadingSession>);

/// 実績バッジコレクション画面。
///
/// 獲得済み/未獲得のバッジをカテゴリ別に俯瞰する。
class BadgeCollectionScreen extends StatefulWidget {
  /// データソース（テスト注入用）。null なら本番 Hive 実装。
  final BadgeCollectionDataSource? dataSource;

  /// バッジ進捗の計算サービス。
  final AchievementBadgeService service;

  /// 実時計の注入（テストの決定論化用）。未指定なら実時計。
  final DateTime Function()? now;

  const BadgeCollectionScreen({
    super.key,
    this.dataSource,
    this.service = const AchievementBadgeService(),
    this.now,
  });

  @override
  State<BadgeCollectionScreen> createState() => _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState extends State<BadgeCollectionScreen> {
  late final Future<_BadgeData> _dataFuture = _load();

  Future<_BadgeData> _load() async {
    final source = widget.dataSource ?? _HiveBadgeDataSource();
    final results = await Future.wait([
      source.getBooks(),
      source.getReviews(),
      source.getSessions(),
    ]);
    return (
      results[0] as List<Book>,
      results[1] as List<Review>,
      results[2] as List<ReadingSession>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('実績バッジ'),
        key: AppKeys.badgeCollectionScreen,
      ),
      body: FutureBuilder<_BadgeData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const _BadgeEmpty(message: 'バッジを読み込めませんでした。');
          }
          final (books, reviews, sessions) = snapshot.data!;
          final collection = widget.service.build(
            books: books,
            reviews: reviews,
            sessions: sessions,
            now: widget.now,
          );
          if (collection.totalCount == 0) {
            return const _BadgeEmpty(message: 'まだ実績バッジがありません。');
          }
          return _BadgeListView(collection: collection);
        },
      ),
    );
  }
}

/// 空状態・エラー状態の表示。
class _BadgeEmpty extends StatelessWidget {
  final String message;

  const _BadgeEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        key: AppKeys.badgeEmpty,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 48),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    );
  }
}

/// サマリー・絞込・カテゴリ別セクションを並べる本体リスト。
class _BadgeListView extends StatefulWidget {
  final AchievementBadgeCollection collection;

  const _BadgeListView({required this.collection});

  @override
  State<_BadgeListView> createState() => _BadgeListViewState();
}

class _BadgeListViewState extends State<_BadgeListView> {
  _BadgeFilter _filter = _BadgeFilter.all;

  List<AchievementBadgeProgress> _visibleOf(
    List<AchievementBadgeProgress> list,
  ) {
    switch (_filter) {
      case _BadgeFilter.all:
        return list;
      case _BadgeFilter.earned:
        return list.where((p) => p.isEarned).toList();
      case _BadgeFilter.unearned:
        return list.where((p) => !p.isEarned).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final grouped = collection.groupByCategory;
    final children = <Widget>[
      _SummaryCard(collection: collection),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: AppKeys.badgeFilterAll,
              label: const Text('すべて'),
              selected: _filter == _BadgeFilter.all,
              onSelected: (_) => setState(() => _filter = _BadgeFilter.all),
            ),
            ChoiceChip(
              key: AppKeys.badgeFilterEarned,
              label: const Text('獲得済み'),
              selected: _filter == _BadgeFilter.earned,
              onSelected: (_) => setState(() => _filter = _BadgeFilter.earned),
            ),
            ChoiceChip(
              key: AppKeys.badgeFilterUnearned,
              label: const Text('未獲得'),
              selected: _filter == _BadgeFilter.unearned,
              onSelected: (_) => setState(() => _filter = _BadgeFilter.unearned),
            ),
          ],
        ),
      ),
    ];

    var visibleAny = false;
    for (final category in AchievementCategory.values) {
      final visible = _visibleOf(grouped[category] ?? const []);
      if (visible.isEmpty) continue;
      visibleAny = true;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${category.icon} ${category.label}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (final progress in visible) {
        children.add(_BadgeRow(progress: progress));
      }
    }
    if (!visibleAny) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('該当するバッジはありません。')),
        ),
      );
    }

    return ListView(children: children);
  }
}

/// 獲得率のサマリーカード。
class _SummaryCard extends StatelessWidget {
  final AchievementBadgeCollection collection;

  const _SummaryCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏅 ${collection.summaryLabel}',
              key: AppKeys.badgeSummaryLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: collection.completionRatio),
          ],
        ),
      ),
    );
  }
}

/// 1バッジの行。
class _BadgeRow extends StatelessWidget {
  final AchievementBadgeProgress progress;

  const _BadgeRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    final definition = progress.definition;
    final earned = progress.isEarned;
    return Card(
      key: AppKeys.badgeRow(definition.id),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (earned)
              Text(definition.category.icon, style: const TextStyle(fontSize: 28))
            else
              Opacity(
                opacity: 0.55,
                child: Icon(
                  Icons.lock,
                  size: 28,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress.ratio),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        progress.progressLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        progress.remainingLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: earned
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
