import 'dart:async';

import 'package:flutter/material.dart';
import 'package:book_review_app/core/input/draft_store.dart';
import 'package:book_review_app/core/input/guarded_dialog.dart';
import 'package:book_review_app/core/input/unsaved_changes.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/book_notes_screen.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_card.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_form.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// レビュー一覧画面
///
/// 指定された書籍（bookId）のレビューを一覧表示する。
/// レビューの追加、編集、削除機能を提供する。
/// [noteRepository] が渡された場合は読書メモ・引用画面への導線を表示する。
///
/// [draftStore] が渡された場合は、入力途中のレビュー本文を下書きとして保存し、
/// 誤って閉じても復元できる（保存成功時にのみ下書きを消す）。
class ReviewScreen extends StatefulWidget {
  final String bookId;
  final ReviewRepository reviewRepository;

  /// 読書メモ・引用リポジトリ（未指定なら導線を表示しない）
  final BookNoteRepository? noteRepository;

  /// 下書きの保存先（未指定なら下書き機能なし＝既存挙動）
  final DraftStore? draftStore;

  const ReviewScreen({
    super.key,
    required this.bookId,
    required this.reviewRepository,
    this.noteRepository,
    this.draftStore,
  });

  /// 新規レビュー下書きのキー。
  static String draftKeyForNew(String bookId) => 'review_new:$bookId';

  /// 編集レビュー下書きのキー。
  static String draftKeyForEdit(String reviewId) => 'review_edit:$reviewId';

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

  Future<void> _addReview(Review review, String draftKey) async {
    try {
      await widget.reviewRepository.addReview(review);
      // 保存に成功したときだけ下書きを消す（失敗時は入力消失を防ぐ）。
      // 下書き削除は後片付けゆえ、完了を待たずに一覧を更新する
      // （実ストレージの I/O が遅い/詰まっても保存導線を止めない）。
      unawaited(widget.draftStore?.clear(draftKey) ?? Future<void>.value());
    } catch (e) {
      _showSaveFailure();
      return;
    }
    await _loadReviews();
  }

  Future<void> _updateReview(Review review, String draftKey) async {
    try {
      await widget.reviewRepository.updateReview(review);
      unawaited(widget.draftStore?.clear(draftKey) ?? Future<void>.value());
    } catch (e) {
      _showSaveFailure();
      return;
    }
    await _loadReviews();
  }

  void _showSaveFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存に失敗しました。入力内容は下書きに残しています。')),
    );
  }

  Future<void> _deleteReview(String id) async {
    await widget.reviewRepository.deleteReview(id);
    await _loadReviews();
  }

  void _showAddDialog() {
    final formKey = GlobalKey<ReviewFormState>();
    final draftKey = ReviewScreen.draftKeyForNew(widget.bookId);
    showGuardedDialog<void>(
      context: context,
      isDirty: () => formKey.currentState?.isDirty ?? false,
      message: UnsavedChangesGuard.confirmMessage(
        draftKept: widget.draftStore != null,
      ),
      builder: (dialogContext) {
        return AlertDialog(
          content: ReviewForm(
            key: formKey,
            bookId: widget.bookId,
            draftStore: widget.draftStore,
            draftKey: draftKey,
            onSave: (review) {
              Navigator.of(dialogContext).pop();
              _addReview(review, draftKey);
            },
            onCancel: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        );
      },
    );
  }

  void _showEditDialog(Review review) {
    final formKey = GlobalKey<ReviewFormState>();
    final draftKey = ReviewScreen.draftKeyForEdit(review.id);
    showGuardedDialog<void>(
      context: context,
      isDirty: () => formKey.currentState?.isDirty ?? false,
      message: UnsavedChangesGuard.confirmMessage(
        draftKept: widget.draftStore != null,
      ),
      builder: (dialogContext) {
        return AlertDialog(
          content: ReviewForm(
            key: formKey,
            bookId: widget.bookId,
            review: review,
            draftStore: widget.draftStore,
            draftKey: draftKey,
            onSave: (updated) {
              Navigator.of(dialogContext).pop();
              _updateReview(updated, draftKey);
            },
            onCancel: () {
              Navigator.of(dialogContext).pop();
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

  /// 読書メモ・引用画面へ遷移する
  void _openNotes() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookNotesScreen(
          bookId: widget.bookId,
          repository: widget.noteRepository!,
          draftStore: widget.draftStore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_review'),
      appBar: AppBar(
        title: const Text('レビュー'),
        actions: [
          if (widget.noteRepository != null)
            SemanticHelper.interactive(
              testId: 'review_open_notes',
              label: '読書メモ・引用を開く',
              child: IconButton(
                key: const Key('open_notes_button'),
                icon: const Icon(Icons.sticky_note_2_outlined),
                tooltip: '読書メモ・引用',
                onPressed: _openNotes,
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: SemanticHelper.interactive(
        testId: 'review_add',
        label: 'レビューを追加',
        child: FloatingActionButton(
          key: const Key('review_add_fab'),
          onPressed: _showAddDialog,
          child: const Icon(Icons.add),
        ),
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
        return SemanticHelper.container(
          testId: SemanticHelper.createTestId('item_review', review.id),
          label: 'レビュー: 評価${review.rating}',
          child: ReviewCard(
            key: ValueKey('review_card_${review.id}'),
            review: review,
            onEdit: () => _showEditDialog(review),
            onDelete: () => _showDeleteConfirmation(review.id),
          ),
        );
      },
    );
  }
}
