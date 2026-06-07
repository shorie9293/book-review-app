import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_card.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_form.dart';

/// レビュー一覧画面
///
/// 指定された書籍（bookId）のレビューを一覧表示する。
/// レビューの追加、編集、削除機能を提供する。
class ReviewScreen extends StatefulWidget {
  final String bookId;
  final ReviewRepository reviewRepository;

  const ReviewScreen({
    super.key,
    required this.bookId,
    required this.reviewRepository,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final reviews = await widget.reviewRepository.getReviewsByBookId(
        widget.bookId,
      );
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addReview(Review review) async {
    await widget.reviewRepository.addReview(review);
    await _loadReviews();
  }

  Future<void> _updateReview(Review review) async {
    await widget.reviewRepository.updateReview(review);
    await _loadReviews();
  }

  Future<void> _deleteReview(String id) async {
    await widget.reviewRepository.deleteReview(id);
    await _loadReviews();
  }

  void _showAddDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: ReviewForm(
            bookId: widget.bookId,
            onSave: (review) {
              Navigator.of(context).pop();
              _addReview(review);
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  void _showEditDialog(Review review) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: ReviewForm(
            bookId: widget.bookId,
            review: review,
            onSave: (updated) {
              Navigator.of(context).pop();
              _updateReview(updated);
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('レビューを削除'),
          content: const Text('このレビューを削除してもよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              key: const Key('review_delete_confirm_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteReview(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_review'),
      appBar: AppBar(title: const Text('レビュー')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        key: const Key('review_add_fab'),
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        key: Key('review_loading_state'),
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text('エラー: $_errorMessage'),
      );
    }

    if (_reviews.isEmpty) {
      return const Center(
        key: Key('review_empty_state'),
        child: Text('レビューはまだありません'),
      );
    }

    return ListView.builder(
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return ReviewCard(
          key: ValueKey('review_card_${review.id}'),
          review: review,
          onEdit: () => _showEditDialog(review),
          onDelete: () => _showDeleteConfirmation(review.id),
        );
      },
    );
  }
}
