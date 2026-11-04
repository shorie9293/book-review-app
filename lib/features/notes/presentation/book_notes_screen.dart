import 'dart:async';

import 'package:flutter/material.dart';
import 'package:book_review_app/core/input/draft_store.dart';
import 'package:book_review_app/core/input/guarded_dialog.dart';
import 'package:book_review_app/core/input/unsaved_changes.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/viewmodel/book_notes_view_model.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_card.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_form.dart';
import 'package:book_review_app/features/undo/domain/undo_buffer.dart';
import 'package:book_review_app/features/undo/presentation/undo_snack_bar.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 読書メモ・引用の一覧画面。
///
/// 指定書籍（bookId）に紐づくメモをページ番号付きで一覧表示し、
/// 種別・キーワードでの絞り込み、追加・編集・削除を提供する。
///
/// [draftStore] が渡された場合は、入力途中の本文・ページ・タグを下書きとして
/// 保存し、誤って閉じても復元できる（保存成功時にのみ下書きを消す）。
class BookNotesScreen extends StatefulWidget {
  final String bookId;
  final BookNoteRepository repository;
  final String? bookTitle;

  /// 下書きの保存先（未指定なら下書き機能なし＝既存挙動）
  final DraftStore? draftStore;

  const BookNotesScreen({
    super.key,
    required this.bookId,
    required this.repository,
    this.bookTitle,
    this.draftStore,
  });

  /// 新規メモ下書きのキー。
  static String draftKeyForNew(String bookId) => 'note_new:$bookId';

  /// 編集メモ下書きのキー。
  static String draftKeyForEdit(String noteId) => 'note_edit:$noteId';

  @override
  State<BookNotesScreen> createState() => _BookNotesScreenState();
}

class _BookNotesScreenState extends State<BookNotesScreen> {
  final BookNotesViewModel _viewModel = BookNotesViewModel();
  final TextEditingController _searchController = TextEditingController();

  /// 直近に削除したメモ（「元に戻す」用・単一スロット）。
  final UndoBuffer<BookNote> _undoBuffer = UndoBuffer<BookNote>();

  @override
  void initState() {
    super.initState();
    _viewModel.loadNotes(widget.repository, widget.bookId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// メモを保存する（成功時のみ下書きを消す）。
  Future<void> _addNote(BookNote note, String draftKey) async {
    try {
      await _viewModel.addNote(widget.repository, note);
      // 下書き削除は後片付けゆえ、完了を待たない。
      unawaited(widget.draftStore?.clear(draftKey) ?? Future<void>.value());
    } catch (e) {
      _showSaveFailure();
    }
  }

  /// メモを更新する（成功時のみ下書きを消す）。
  Future<void> _updateNote(BookNote note, String draftKey) async {
    try {
      await _viewModel.updateNote(widget.repository, note);
      unawaited(widget.draftStore?.clear(draftKey) ?? Future<void>.value());
    } catch (e) {
      _showSaveFailure();
    }
  }

  void _showSaveFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存に失敗しました。入力内容は下書きに残しています。')),
    );
  }

  void _showAddDialog() {
    final formKey = GlobalKey<NoteFormState>();
    final draftKey = BookNotesScreen.draftKeyForNew(widget.bookId);
    showGuardedDialog<void>(
      context: context,
      isDirty: () => formKey.currentState?.isDirty ?? false,
      message: UnsavedChangesGuard.confirmMessage(
        draftKept: widget.draftStore != null,
      ),
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('メモを追加'),
          content: NoteForm(
            key: formKey,
            bookId: widget.bookId,
            draftStore: widget.draftStore,
            draftKey: draftKey,
            onSave: (note) {
              navigator.pop();
              _addNote(note, draftKey);
            },
            onCancel: () => navigator.pop(),
          ),
        );
      },
    );
  }

  void _showEditDialog(BookNote note) {
    final formKey = GlobalKey<NoteFormState>();
    final draftKey = BookNotesScreen.draftKeyForEdit(note.id);
    showGuardedDialog<void>(
      context: context,
      isDirty: () => formKey.currentState?.isDirty ?? false,
      message: UnsavedChangesGuard.confirmMessage(
        draftKept: widget.draftStore != null,
      ),
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('メモを編集'),
          content: NoteForm(
            key: formKey,
            bookId: widget.bookId,
            note: note,
            draftStore: widget.draftStore,
            draftKey: draftKey,
            onSave: (updated) {
              navigator.pop();
              _updateNote(updated, draftKey);
            },
            onCancel: () => navigator.pop(),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(BookNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('メモを削除'),
          content: const Text('このメモを削除してもよろしいですか？'),
          actions: [
            TextButton(
              key: const Key('note_delete_cancel_button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              key: const Key('note_delete_confirm_button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // 削除対象を保持 → 削除実行（既存の確認ダイアログ・即時削除挙動は不変）
      _undoBuffer.push(note);
      await _viewModel.deleteNote(widget.repository, note.id);
      if (!mounted) return;
      showUndoSnackBar(
        context,
        message: 'メモを削除しました',
        onUndo: () async {
          final restored = _undoBuffer.take();
          if (restored == null) return;
          // addNote は id をキーに保存するため、削除前と同じ id で復元される。
          await _viewModel.addNote(widget.repository, restored);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_book_notes'),
      appBar: AppBar(
        title: Text(
          widget.bookTitle == null ? '読書メモ' : '読書メモ: ${widget.bookTitle}',
        ),
      ),
      floatingActionButton: SemanticHelper.interactive(
        testId: 'notes_add_note',
        label: 'メモを追加',
        child: FloatingActionButton(
          key: const Key('note_add_fab'),
          onPressed: _showAddDialog,
          tooltip: 'メモを追加',
          child: const Icon(Icons.add),
        ),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(
        key: Key('note_loading_state'),
        child: CircularProgressIndicator(),
      );
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        key: const Key('note_error_state'),
        child: Text('エラー: ${_viewModel.errorMessage}'),
      );
    }

    final visible = _viewModel.visibleNotes;

    return Column(
      children: [
        _buildSummary(),
        _buildFilters(),
        const Divider(height: 1),
        Expanded(child: _buildList(visible)),
      ],
    );
  }

  Widget _buildSummary() {
    final counts = _viewModel.countByKind;
    final range = _viewModel.pageRange;
    final rangeLabel = range.isEmpty
        ? 'ページ記録なし'
        : 'p.${range.min}〜p.${range.max}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        key: const Key('note_summary'),
        children: [
          Text(
            'メモ ${counts[NoteKind.memo] ?? 0}件 ・ 引用 ${counts[NoteKind.quote] ?? 0}件',
            style: const TextStyle(fontSize: 13),
          ),
          const Spacer(),
          Text(
            rangeLabel,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              SemanticHelper.toggle(
                testId: 'notes_filter_all',
                value: _viewModel.kindFilter == null,
                onChanged: (_) => _viewModel.setKindFilter(null),
                child: ChoiceChip(
                  key: const Key('note_filter_all'),
                  label: const Text('すべて'),
                  selected: _viewModel.kindFilter == null,
                  onSelected: (_) => _viewModel.setKindFilter(null),
                ),
              ),
              const SizedBox(width: 8),
              SemanticHelper.toggle(
                testId: 'notes_filter_memo',
                value: _viewModel.kindFilter == NoteKind.memo,
                onChanged: (_) => _viewModel.setKindFilter(NoteKind.memo),
                child: ChoiceChip(
                  key: const Key('note_filter_memo'),
                  label: const Text('メモ'),
                  selected: _viewModel.kindFilter == NoteKind.memo,
                  onSelected: (_) => _viewModel.setKindFilter(NoteKind.memo),
                ),
              ),
              const SizedBox(width: 8),
              SemanticHelper.toggle(
                testId: 'notes_filter_quote',
                value: _viewModel.kindFilter == NoteKind.quote,
                onChanged: (_) => _viewModel.setKindFilter(NoteKind.quote),
                child: ChoiceChip(
                  key: const Key('note_filter_quote'),
                  label: const Text('引用'),
                  selected: _viewModel.kindFilter == NoteKind.quote,
                  onSelected: (_) => _viewModel.setKindFilter(NoteKind.quote),
                ),
              ),
            ],
          ),
          SemanticHelper.textField(
            testId: 'notes_search_field',
            label: '本文・タグで検索',
            child: TextField(
              key: const Key('note_search_field'),
              controller: _searchController,
              onChanged: _viewModel.setKeyword,
              decoration: const InputDecoration(
                hintText: '本文・タグで検索',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<BookNote> notes) {
    if (notes.isEmpty) {
      return const Center(
        key: Key('note_empty_state'),
        child: Text('メモはまだありません'),
      );
    }

    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return SemanticHelper.container(
          testId: SemanticHelper.createTestId('item_note', note.id),
          label: note.isFavorite
              ? 'メモ: ${note.content}（お気に入り済み）'
              : 'メモ: ${note.content}',
          child: NoteCard(
            key: ValueKey('note_card_${note.id}'),
            note: note,
            onEdit: () => _showEditDialog(note),
            onDelete: () => _showDeleteConfirmation(note),
            onToggleFavorite: () =>
                _viewModel.toggleFavorite(widget.repository, note),
          ),
        );
      },
    );
  }
}
