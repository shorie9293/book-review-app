import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/viewmodel/book_notes_view_model.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_card.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_form.dart';

/// 読書メモ・引用の一覧画面。
///
/// 指定書籍（bookId）に紐づくメモをページ番号付きで一覧表示し、
/// 種別・キーワードでの絞り込み、追加・編集・削除を提供する。
class BookNotesScreen extends StatefulWidget {
  final String bookId;
  final BookNoteRepository repository;
  final String? bookTitle;

  const BookNotesScreen({
    super.key,
    required this.bookId,
    required this.repository,
    this.bookTitle,
  });

  @override
  State<BookNotesScreen> createState() => _BookNotesScreenState();
}

class _BookNotesScreenState extends State<BookNotesScreen> {
  final BookNotesViewModel _viewModel = BookNotesViewModel();
  final TextEditingController _searchController = TextEditingController();

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

  void _showAddDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('メモを追加'),
          content: NoteForm(
            bookId: widget.bookId,
            onSave: (note) {
              navigator.pop();
              _viewModel.addNote(widget.repository, note);
            },
            onCancel: () => navigator.pop(),
          ),
        );
      },
    );
  }

  void _showEditDialog(BookNote note) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('メモを編集'),
          content: NoteForm(
            bookId: widget.bookId,
            note: note,
            onSave: (updated) {
              navigator.pop();
              _viewModel.updateNote(widget.repository, updated);
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
      await _viewModel.deleteNote(widget.repository, note.id);
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
      floatingActionButton: FloatingActionButton(
        key: const Key('note_add_fab'),
        onPressed: _showAddDialog,
        tooltip: 'メモを追加',
        child: const Icon(Icons.add),
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
              ChoiceChip(
                key: const Key('note_filter_all'),
                label: const Text('すべて'),
                selected: _viewModel.kindFilter == null,
                onSelected: (_) => _viewModel.setKindFilter(null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const Key('note_filter_memo'),
                label: const Text('メモ'),
                selected: _viewModel.kindFilter == NoteKind.memo,
                onSelected: (_) => _viewModel.setKindFilter(NoteKind.memo),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const Key('note_filter_quote'),
                label: const Text('引用'),
                selected: _viewModel.kindFilter == NoteKind.quote,
                onSelected: (_) => _viewModel.setKindFilter(NoteKind.quote),
              ),
            ],
          ),
          TextField(
            key: const Key('note_search_field'),
            controller: _searchController,
            onChanged: _viewModel.setKeyword,
            decoration: const InputDecoration(
              hintText: '本文・タグで検索',
              prefixIcon: Icon(Icons.search),
              isDense: true,
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
        return NoteCard(
          key: ValueKey('note_card_${note.id}'),
          note: note,
          onEdit: () => _showEditDialog(note),
          onDelete: () => _showDeleteConfirmation(note),
        );
      },
    );
  }
}
