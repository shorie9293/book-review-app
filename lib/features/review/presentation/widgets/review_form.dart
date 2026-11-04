import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:book_review_app/core/input/draft_store.dart';
import 'package:book_review_app/core/input/unsaved_changes.dart';
import 'package:book_review_app/domain/models/review.dart';

/// レビューフォームウィジェット
///
/// 新規レビューの作成または既存レビューの編集に使用する。
/// 星評価（1〜5）の選択、テキスト入力（最大500文字）、保存/キャンセル機能を提供する。
///
/// [draftStore] と [draftKey] を渡すと、入力途中の本文を下書きとして保存し、
/// 開き直したときに復元する（保存成功後の削除は呼び出し側の責務）。
class ReviewForm extends StatefulWidget {
  final String bookId;
  final Review? review;
  final ValueChanged<Review> onSave;
  final VoidCallback onCancel;

  /// 下書きの保存先（null なら下書き機能なし）。
  final DraftStore? draftStore;

  /// 下書きのキー（[draftStore] 指定時のみ使う）。
  final String? draftKey;

  const ReviewForm({
    super.key,
    required this.bookId,
    required this.onSave,
    required this.onCancel,
    this.review,
    this.draftStore,
    this.draftKey,
  });

  @override
  State<ReviewForm> createState() => ReviewFormState();
}

/// フォームの状態（破棄確認のため、未保存の変更を外から問い合わせられる）。
class ReviewFormState extends State<ReviewForm> {
  late int _rating;
  late TextEditingController _textController;

  /// 開いた時点の値（破棄判定の基準）。
  late final String _initialText;
  late final int _initialRating;

  @override
  void initState() {
    super.initState();
    _initialRating = widget.review?.rating ?? 0;
    _initialText = widget.review?.text ?? '';
    _rating = _initialRating;
    _textController = TextEditingController(text: _initialText);
    _restoreDraft();
  }

  /// 未保存の変更があるか（空白差・評価の変化のみは未変更）。
  bool get isDirty =>
      UnsavedChangesGuard.isDirty(_initialText, _textController.text) ||
      _rating != _initialRating;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _encodeDraft() => json.encode({
        'text': _textController.text,
        'rating': _rating,
      });

  /// 下書きを復元する（本文が空のときだけ・破損は無視）。
  Future<void> _restoreDraft() async {
    final store = widget.draftStore;
    final key = widget.draftKey;
    if (store == null || key == null) return;

    final raw = await store.read(key);
    if (raw == null || !mounted) return;

    final decoded = decodeDraftJson(raw);
    final text = decoded?['text'] as String? ?? raw;
    final rating = decoded?['rating'];
    if (text.trim().isEmpty) return;

    setState(() {
      _textController.text = text;
      if (rating is int && rating >= 1 && rating <= 5) _rating = rating;
    });
  }

  /// 入力のたびに下書きを書く（空になったら消す）。
  ///
  /// タイマーを使わないので、試練は待ち時間なしで決定的に撃てる。
  void _persistDraft() {
    final store = widget.draftStore;
    final key = widget.draftKey;
    if (store == null || key == null) return;
    unawaited(store.write(key, _encodeDraft()));
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
        _persistDraft();
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
            onChanged: (_) => _persistDraft(),
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
