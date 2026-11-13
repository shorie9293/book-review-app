import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/time/local_calendar_date.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/review/domain/review_query.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' show SemanticHelper;

/// レビューの横断検索画面
///
/// 蔵書すべてのレビューを読み込み、本文・書名の部分一致（空白区切りは AND）で
/// 絞り込んで一覧表示する。各行をタップすると該当本のレビュー画面へ遷移する。
///
/// 既存の [BookRepository] / [ReviewRepository] のみで完結し、
/// リポジトリインタフェースには一切手を加えない。
class ReviewSearchScreen extends StatefulWidget {
  final BookRepository bookRepository;
  final ReviewRepository reviewRepository;

  /// 初期検索語（本棚からの引き継ぎ用）
  final String initialQuery;

  /// 結果行タップ時の遷移先ビルダー（未指定なら実画面 [ReviewScreen] を push）
  final Widget Function(BuildContext context, String bookId)? reviewScreenBuilder;

  const ReviewSearchScreen({
    super.key,
    required this.bookRepository,
    required this.reviewRepository,
    this.initialQuery = '',
    this.reviewScreenBuilder,
  });

  @override
  State<ReviewSearchScreen> createState() => _ReviewSearchScreenState();
}

class _ReviewSearchScreenState extends State<ReviewSearchScreen> {
  late final TextEditingController _controller;

  List<Review> _reviews = const [];
  Map<String, String> _titles = const {};

  bool _loading = true;

  /// 読み込み失敗時のメッセージ（0件表示と混同しないための専用状態）
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final books = await widget.bookRepository.getBooks();
      final titles = <String, String>{
        for (final book in books) book.id: book.title,
      };
      final reviews = <Review>[];
      for (final book in books) {
        reviews.addAll(await widget.reviewRepository.getReviewsByBookId(book.id));
      }
      if (!mounted) return;
      setState(() {
        _titles = titles;
        _reviews = reviews;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviews = const [];
        _titles = const {};
        _loading = false;
        _errorMessage = 'レビューの読み込みに失敗しました';
      });
    }
  }

  /// 保存された瞬間を **ローカル暦** の `yyyy/M/d` で表示する。
  /// UTC 種別の [DateTime] を直読みすると UTC 暦になり、JST 早朝の
  /// レビューが前日表示になるため正準関数へ委譲する。
  String _formatDate(DateTime date) => formatLocalDate(date);

  void _openReview(String bookId) {
    final builder = widget.reviewScreenBuilder;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => builder != null
            ? builder(context, bookId)
            : ReviewScreen(
                bookId: bookId,
                reviewRepository: widget.reviewRepository,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.reviewSearchScreen,
      appBar: AppBar(title: const Text('レビューを検索')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SemanticHelper.textField(
                testId: 'review_search_field',
                label: 'レビューを検索',
                child: TextField(
                  key: AppKeys.reviewSearchField,
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '本文・書名で検索',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Expanded(child: _buildError())
              else
                Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        key: AppKeys.reviewSearchError,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          SemanticHelper.interactive(
            testId: 'review_search_retry',
            label: '再試行',
            child: OutlinedButton.icon(
              key: AppKeys.reviewSearchRetry,
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final results = ReviewQueryService.apply(
      _reviews,
      _titles,
      ReviewQuery(text: _controller.text),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${results.length}件',
            key: AppKeys.reviewSearchCount,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Column(
                    key: AppKeys.reviewSearchEmpty,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('該当するレビューがありません'),
                      SizedBox(height: 4),
                      Text('検索語を変えてお試しください'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final review = result.review;
                    return ListTile(
                      key: AppKeys.reviewSearchRow(review.id),
                      title: Text(result.bookTitle ?? '（書名不明）'),
                      subtitle: Text(
                        '${_formatDate(review.createdAt)}\n'
                        '${ReviewQueryService.excerpt(review.text, maxLength: 80)}',
                      ),
                      isThreeLine: true,
                      onTap: () => _openReview(review.bookId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
