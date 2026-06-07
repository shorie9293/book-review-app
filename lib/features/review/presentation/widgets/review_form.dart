import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:book_review_app/domain/models/review.dart';

/// レビューフォームウィジェット
///
/// 新規レビューの作成または既存レビューの編集に使用する。
/// 星評価（1〜5）の選択、テキスト入力（最大500文字）、保存/キャンセル機能を提供する。
class ReviewForm extends StatefulWidget {
  final String bookId;
  final Review? review;
  final ValueChanged<Review> onSave;
  final VoidCallback onCancel;

  const ReviewForm({
    super.key,
    required this.bookId,
    required this.onSave,
    required this.onCancel,
    this.review,
  });

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  late int _rating;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _rating = widget.review?.rating ?? 0;
    _textController =
        TextEditingController(text: widget.review?.text ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onSave() {
    final review = Review(
      id: widget.review?.id ?? const Uuid().v4(),
      bookId: widget.bookId,
      rating: _rating,
      text: _textController.text,
      createdAt: widget.review?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    widget.onSave(review);
  }

  Widget _buildStar(int index) {
    final starIndex = index + 1; // 1-based rating
    final isFilled = starIndex <= _rating;
    return IconButton(
      key: Key('review_form_star_$index'),
      icon: Icon(isFilled ? Icons.star : Icons.star_border),
      color: Colors.amber,
      onPressed: () {
        setState(() {
          _rating = starIndex;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('review_form'),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Star rating selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => _buildStar(index)),
          ),
          const SizedBox(height: 16),
          // Review text field
          TextField(
            key: const Key('review_form_text_field'),
            controller: _textController,
            maxLines: 5,
            maxLength: 500,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'レビュー内容',
              hintText: 'この書籍の感想を書いてください...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Save/Cancel buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('review_form_cancel_button'),
                onPressed: widget.onCancel,
                child: const Text('キャンセル'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('review_form_save_button'),
                onPressed: _rating > 0 ? _onSave : null,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
