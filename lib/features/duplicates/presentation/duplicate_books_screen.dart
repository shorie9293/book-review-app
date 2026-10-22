import 'package:book_review_app/core/haptics.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/duplicates/domain/duplicate_book_group.dart';
import 'package:book_review_app/features/duplicates/domain/duplicate_book_service.dart';
import 'package:flutter/material.dart';

/// 重複した蔵書を検出し、代表を選んで1冊に統合する画面。
///
/// 検出・統合計画は純粋な [DuplicateBookService] に委ね、この画面は
/// 選択状態の保持とリポジトリ操作（統合・削除・関連データの移行）のみを担う。
/// 処理後はリポジトリを再読込せず、ローカル状態を更新する
/// （`booksOverride` 経路でも正しく動くようにするため）。
class DuplicateBooksScreen extends StatefulWidget {
  const DuplicateBooksScreen({
    super.key,
    required this.repository,
    this.noteRepository,
    this.reviewRepository,
    this.booksOverride,
  });

  /// 蔵書リポジトリ（統合・削除の永続化）。
  final BookRepository repository;

  /// メモのリポジトリ（指定時は代表へメモを移行する）。
  final BookNoteRepository? noteRepository;

  /// レビューのリポジトリ（指定時は代表へレビューを移行する）。
  final ReviewRepository? reviewRepository;

  /// 試練用の蔵書上書き（指定時は [repository] の getBooks を使わない）。
  final List<Book>? booksOverride;

  @override
  State<DuplicateBooksScreen> createState() => _DuplicateBooksScreenState();
}

class _DuplicateBooksScreenState extends State<DuplicateBooksScreen> {
  List<Book> _books = const [];
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  /// 組ごとに選択中の代表 id（isbnKey -> bookId）。
  final Map<String, String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final books =
          widget.booksOverride ?? await widget.repository.getBooks();
      if (!mounted) return;
      setState(() {
        _books = List<Book>.of(books);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '蔵書の読み込みに失敗しました: $e';
      });
    }
  }

  List<DuplicateBookGroup> get _groups =>
      DuplicateBookService.findGroups(_books);

  /// 組の選択中 id（未選択・組から消えた id は代表へフォールバック）。
  String _selectedIdOf(DuplicateBookGroup group) {
    final selected = _selectedIds[group.isbnKey];
    if (selected != null && group.bookIds.contains(selected)) return selected;
    return group.representative.id;
  }

  void _select(DuplicateBookGroup group, String bookId) {
    setState(() => _selectedIds[group.isbnKey] = bookId);
  }

  /// 統合後にローカル状態から組の代表以外を除き、代表を統合後の蔵書へ差し替える。
  void _applyMergeLocally(
    DuplicateBookGroup group,
    DuplicateMergePlan plan,
  ) {
    final groupIds = group.bookIds.toSet();
    final updated = <Book>[
      for (final book in _books)
        if (book.id == plan.merged.id)
          plan.merged
        else if (!groupIds.contains(book.id))
          book,
    ];
    _selectedIds.remove(group.isbnKey);
    setState(() => _books = updated);
  }

  Future<void> _confirmAndMerge(DuplicateBookGroup group) async {
    if (_busy) return;
    final keepId = _selectedIdOf(group);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重複を統合'),
        content: Text('重複した ${group.count} 冊を1冊に統合します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('統合する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final plan = DuplicateBookService.planMerge(group, keepId);
      await widget.repository.updateBook(plan.merged);
      for (final removedId in plan.removedIds) {
        await _migrateRelated(removedId, plan.merged.id);
        await widget.repository.removeBook(removedId);
      }
      if (!mounted) return;
      _applyMergeLocally(group, plan);
      hapticTap();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${plan.removedCount}冊を1冊に統合しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('統合に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 削除される蔵書のメモ・レビューを代表蔵書へ付け替える。
  ///
  /// メモは [BookNote.copyWith] が bookId を変えられないため、
  /// 同じ id のまま bookId だけ差し替えた新しい [BookNote] を構築する。
  Future<void> _migrateRelated(String fromId, String toId) async {
    final noteRepository = widget.noteRepository;
    if (noteRepository != null) {
      final notes = await noteRepository.getNotesByBookId(fromId);
      for (final note in notes) {
        await noteRepository.updateNote(
          BookNote(
            id: note.id,
            bookId: toId,
            kind: note.kind,
            content: note.content,
            pageNumber: note.pageNumber,
            tags: note.tags,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            isFavorite: note.isFavorite,
          ),
        );
      }
    }

    final reviewRepository = widget.reviewRepository;
    if (reviewRepository != null) {
      final reviews = await reviewRepository.getReviewsByBookId(fromId);
      for (final review in reviews) {
        await reviewRepository.updateReview(
          Review(
            id: review.id,
            bookId: toId,
            rating: review.rating,
            text: review.text,
            createdAt: review.createdAt,
            updatedAt: review.updatedAt,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDelete(Book book) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('蔵書を削除'),
        content: Text('「${book.title}」を削除します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.repository.removeBook(book.id);
      if (!mounted) return;
      setState(() {
        _books = [
          for (final item in _books)
            if (item.id != book.id) item,
        ];
      });
      hapticTap();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1冊を削除しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(title: const Text('重複した蔵書')),
      body: _buildBody(groups),
    );
  }

  Widget _buildBody(List<DuplicateBookGroup> groups) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text(_loadError!));
    }
    return Column(
      children: [
        _buildSummaryCard(groups),
        Expanded(
          child: groups.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) =>
                      _buildGroupCard(groups[index]),
                ),
        ),
      ],
    );
  }

  /// 無効化できないサマリーカード（閉じるボタンを置かない）。
  Widget _buildSummaryCard(List<DuplicateBookGroup> groups) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.library_books_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(DuplicateBookService.summaryLabel(groups))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        key: AppKeys.duplicateEmpty,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.library_add_check_outlined, size: 48),
          SizedBox(height: 8),
          Text('重複した蔵書はありません'),
        ],
      ),
    );
  }

  Widget _buildGroupCard(DuplicateBookGroup group) {
    final selectedId = _selectedIdOf(group);
    return Card(
      key: AppKeys.duplicateGroupCard(group.isbnKey),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.representative.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(group.countLabel),
                ],
              ),
            ),
            Column(
              children: [
                for (final book in group.books)
                  _buildBookRadio(book, selectedId, group),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: AppKeys.duplicateMergeButton(group.isbnKey),
                  onPressed: _busy ? null : () => _confirmAndMerge(group),
                  icon: const Icon(Icons.merge_type, size: 18),
                  label: const Text('この組を統合する'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookRadio(
    Book book,
    String selectedId,
    DuplicateBookGroup group,
  ) {
    return RadioListTile<String>(
      key: AppKeys.duplicateKeepRadio(book.id),
      value: book.id,
      // CI の Flutter 3.27.4 でも動くよう、groupValue/onChanged 方式を使う
      // （3.32 以降の RadioGroup 祖先は旧SDKに存在しない）。
      // ignore: deprecated_member_use
      groupValue: selectedId,
      // ignore: deprecated_member_use
      onChanged: (value) {
        if (value == null) return;
        _select(group, value);
      },
      title: Text(book.title),
      subtitle: Text(
        '追加: ${_formatDate(book.addedAt)}'
        ' / 状態: ${book.readingStatus.label}'
        ' / ${book.currentPage}ページ',
      ),
      secondary: IconButton(
        key: AppKeys.duplicateDeleteButton(book.id),
        icon: const Icon(Icons.delete_outline),
        tooltip: 'この蔵書を削除',
        onPressed: _busy ? null : () => _confirmAndDelete(book),
      ),
    );
  }

  /// 追加日時の表示（yyyy/MM/dd）。未設定は「未設定」。
  String _formatDate(DateTime? value) {
    if (value == null) return '未設定';
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }
}
