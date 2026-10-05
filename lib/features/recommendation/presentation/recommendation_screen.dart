import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:book_review_app/features/recommendation/domain/book_recommendation.dart';
import 'package:book_review_app/features/recommendation/domain/recommendation_service.dart';

/// 「読書の推薦」画面。
///
/// books を注入した場合は reviews の有無にかかわらず即描画する
/// （reviews 未注入なら背景で非同期取得し、描画をブロックしない）。
/// books も reviews も両方 null のときだけ Hive 読込スピナーを出す。
class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({
    super.key,
    this.books,
    this.reviews,
    this.now,
    this.limit = RecommendationService.defaultLimit,
  });

  /// null なら Hive から読み込む（HiveBookRepository）。
  final List<Book>? books;

  /// null なら Hive から読み込む（HiveChallengeRepository.getAllReviews）。
  final List<Review>? reviews;

  /// 未使用（将来用）。
  final DateTime? now;

  final int limit;

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  List<Book>? _books;
  List<Review>? _reviews;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _books = widget.books;
    _reviews = widget.reviews;
    final needsBooks = widget.books == null;
    final needsReviews = widget.reviews == null;
    // 両方 null（何も表示できるものが無い）ときだけスピナーを出す。
    if (needsBooks && needsReviews) {
      _loading = true;
    }
    if (needsBooks || needsReviews) {
      _loadMissing(needsBooks, needsReviews);
    }
  }

  /// 不足しているデータだけを背景で取得し、完了後に反映する。
  /// 失敗しても画面をブロックしない（既存データ or 空のまま描画継続）。
  Future<void> _loadMissing(bool needsBooks, bool needsReviews) async {
    List<Book>? loadedBooks;
    List<Review>? loadedReviews;
    try {
      if (needsBooks) {
        final repository = HiveBookRepository();
        await repository.init();
        loadedBooks = await repository.getBooks();
      }
      if (needsReviews) {
        final repository = HiveChallengeRepository();
        await repository.init();
        loadedReviews = await repository.getAllReviews();
      }
    } catch (_) {
      // 取得失敗は握り潰す（空のまま描画継続）。
    }
    if (!mounted) return;
    setState(() {
      if (loadedBooks != null) _books = loadedBooks;
      if (loadedReviews != null) _reviews = loadedReviews;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.recommendationScreen,
      appBar: AppBar(title: const Text('読書の推薦')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: AppKeys.recommendationLoading,
        child: CircularProgressIndicator(),
      );
    }
    final books = _books ?? const [];
    final reviews = _reviews ?? const [];
    final recommendations = RecommendationService.recommend(
      books: books,
      reviews: reviews,
      limit: widget.limit,
    );
    if (recommendations.isEmpty) {
      return const Center(
        key: AppKeys.recommendationEmpty,
        child: Text('推薦できる積読がありません'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final rec = recommendations[index];
        return _RecommendationCard(recommendation: rec);
      },
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final BookRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final genres = recommendation.matchedGenres;
    return Card(
      key: AppKeys.recommendationCard(recommendation.bookId),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Tooltip(
                  message: '推薦スコア',
                  child: Badge(label: Text('${recommendation.score}')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              recommendation.author,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(recommendation.reason),
            if (genres.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final genre in genres)
                    Chip(
                      key: Key('recommendation_chip_${recommendation.bookId}_$genre'),
                      label: Text(genre),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
