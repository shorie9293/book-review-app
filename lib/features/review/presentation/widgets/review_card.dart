import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/review.dart';

/// レビューカードウィジェット
///
/// レビューの星評価、テキスト内容、日付、編集/削除ボタンを表示する。
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.onDelete,
    required this.onEdit,
  });

  final Review review;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  String _starString(int rating) {
    return '★' * rating + '☆' * (5 - rating);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('review_card'),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 星評価
            Text(
              _starString(review.rating),
              key: const Key('review_card_stars'),
              style: const TextStyle(fontSize: 20, color: Colors.amber),
            ),
            const SizedBox(height: 4),
            // テキスト内容
            Text(
              review.text,
              key: const Key('review_card_text'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            // 日付
            Text(
              '${review.createdAt.year}/${review.createdAt.month}/${review.createdAt.day}',
              key: const Key('review_card_date'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // 編集/削除ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('review_card_edit_button'),
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                ),
                IconButton(
                  key: const Key('review_card_delete_button'),
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
