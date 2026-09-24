import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/reading_status_service.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/notes/presentation/book_notes_screen.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';

/// 蔵書詳細サマリー（純粋Service・UIに依存しない）。
///
/// レビュー・メモ・進捗から詳細画面のサマリー表示に必要な集計値を算出する。
class BookDetailSummary {
  /// レビュー件数
  final int reviewCount;

  /// 評価平均（レビュー0件はnull・1桁目で丸め）
  final double? averageRating;

  /// お気に入りメモ件数
  final int favoriteNoteCount;

  /// メモ件数
  final int memoCount;

  /// 引用件数
  final int quoteCount;

  /// 最終活動日時（reviewsとnotesのupdatedAt最大・両方空はnull）
  final DateTime? lastActivityAt;

  /// 読書進捗ラベル（日本語）
  final String progressLabel;

  /// 不正値を許さない非constコンストラクタ。
  ///
  /// カウントの負値・averageRatingの範囲外（0未満/5超過）は [ArgumentError]。
  BookDetailSummary({
    required this.reviewCount,
    required this.averageRating,
    required this.favoriteNoteCount,
    required this.memoCount,
    required this.quoteCount,
    required this.lastActivityAt,
    required this.progressLabel,
  }) {
    if (reviewCount < 0) {
      throw ArgumentError.value(reviewCount, 'reviewCount',
          'reviewCount must be >= 0');
    }
    if (favoriteNoteCount < 0) {
      throw ArgumentError.value(favoriteNoteCount, 'favoriteNoteCount',
          'favoriteNoteCount must be >= 0');
    }
    if (memoCount < 0) {
      throw ArgumentError.value(
          memoCount, 'memoCount', 'memoCount must be >= 0');
    }
    if (quoteCount < 0) {
      throw ArgumentError.value(
          quoteCount, 'quoteCount', 'quoteCount must be >= 0');
    }
    final double? avg = averageRating;
    if (avg != null && (avg < 0 || avg > 5)) {
      throw ArgumentError.value(avg, 'averageRating',
          'averageRating must be within 0..5');
    }
  }

  /// [book] のレビュー・メモからサマリーを構築する。
  ///
  /// reviewCount / averageRating（0除算ガード・1桁目で丸め） /
  /// favoriteNoteCount / memoCount / quoteCount /
  /// lastActivityAt（reviews・notesのupdatedAt最大値、両方空はnull） /
  /// progressLabel（読書状態に応じた日本語ラベル+ページ・読了日）を算出する。
  static BookDetailSummary build(
    Book book,
    List<Review> reviews,
    List<BookNote> notes,
  ) {
    final reviewCount = reviews.length;
    final double? averageRating;
    if (reviews.isEmpty) {
      averageRating = null;
    } else {
      final sum = reviews.fold<int>(0, (acc, r) => acc + r.rating);
      averageRating = double.parse((sum / reviewCount).toStringAsFixed(1));
    }

    var favoriteNoteCount = 0;
    var memoCount = 0;
    var quoteCount = 0;
    for (final note in notes) {
      if (note.isFavorite) favoriteNoteCount++;
      if (note.kind == NoteKind.memo) {
        memoCount++;
      } else {
        quoteCount++;
      }
    }

    DateTime? lastActivityAt;
    for (final r in reviews) {
      if (lastActivityAt == null || r.updatedAt.isAfter(lastActivityAt)) {
        lastActivityAt = r.updatedAt;
      }
    }
    for (final n in notes) {
      if (lastActivityAt == null || n.updatedAt.isAfter(lastActivityAt)) {
        lastActivityAt = n.updatedAt;
      }
    }

    return BookDetailSummary(
      reviewCount: reviewCount,
      averageRating: averageRating,
      favoriteNoteCount: favoriteNoteCount,
      memoCount: memoCount,
      quoteCount: quoteCount,
      lastActivityAt: lastActivityAt,
      progressLabel: _progressLabel(book),
    );
  }

  /// 読書状態に応じた進捗ラベルを組む。
  ///
  /// - 未読: 「未読」
  /// - 読書中: 「読書中」+ currentPage/pageCount が揃う時は '12/300ページ'
  /// - 読了: 「読了」+ finishedAt があれば 'yyyy/MM/dd'
  static String _progressLabel(Book book) {
    switch (book.readingStatus) {
      case ReadingStatus.unread:
        return '未読';
      case ReadingStatus.reading:
        final base = '読書中';
        final hasPage =
            book.pageCount != null && book.pageCount! > 0;
        if (hasPage) {
          return '$base ${book.currentPage}/${book.pageCount}ページ';
        }
        return base;
      case ReadingStatus.finished:
        final finishedAt = book.finishedAt;
        if (finishedAt != null) {
          final mm = finishedAt.month.toString().padLeft(2, '0');
          final dd = finishedAt.day.toString().padLeft(2, '0');
          return '読了 ${finishedAt.year}/$mm/$dd';
        }
        return '読了';
    }
  }
}

/// 蔵書詳細画面。
///
/// ヘッダー（タイトル・著者・カバー）・サマリーカード・読書進捗・
/// レビュー一覧・メモ/引用一覧を表示する。
/// initState 時にレビューとメモをリポジトリから読み込む。
class BookDetailScreen extends StatefulWidget {
  final Book book;
  final BookRepository bookRepository;
  final ReviewRepository reviewRepository;

  /// メモ・引用リポジトリ（未指定ならメモ一覧は空扱い）
  final BookNoteRepository? noteRepository;

  const BookDetailScreen({
    super.key,
    required this.book,
    required this.bookRepository,
    required this.reviewRepository,
    this.noteRepository,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  List<Review> _reviews = const [];
  List<BookNote> _notes = const [];
  bool _loading = true;

  /// 進行ページ更新で変わった最新の本（widget.book を上書きする）。
  Book? _book;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      widget.reviewRepository.getReviewsByBookId(widget.book.id),
      if (widget.noteRepository != null)
        widget.noteRepository!.getNotesByBookId(widget.book.id)
      else
        Future<List<BookNote>>.value(const []),
    ]);
    if (!mounted) return;
    setState(() {
      _reviews = results[0] as List<Review>;
      _notes = results[1] as List<BookNote>;
      _loading = false;
    });
  }

  void _openReviewScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewScreen(
          bookId: widget.book.id,
          reviewRepository: widget.reviewRepository,
          noteRepository: widget.noteRepository,
        ),
      ),
    );
  }

  void _openNotesScreen() {
    final noteRepository = widget.noteRepository;
    if (noteRepository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookNotesScreen(
          bookId: widget.book.id,
          repository: noteRepository,
          bookTitle: widget.book.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = _book ?? widget.book;
    final summary = BookDetailSummary.build(book, _reviews, _notes);

    return Scaffold(
      appBar: AppBar(title: const Text('蔵書詳細')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(context, book),
                const SizedBox(height: 16),
                _buildSummaryCard(summary),
                const SizedBox(height: 16),
                _buildProgressSection(book),
                const SizedBox(height: 16),
                _buildActionButtons(),
                const SizedBox(height: 16),
                _buildReviewSection(),
                const SizedBox(height: 16),
                _buildNoteSection(),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context, Book book) {
    final cover = book.coverImageUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          height: 112,
          child: cover != null && cover.isNotEmpty
              ? Image.network(cover, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _coverPlaceholder())
              : _coverPlaceholder(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(book.author),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder() => Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book),
      );

  Widget _buildSummaryCard(BookDetailSummary summary) {
    final averageRating = summary.averageRating;
    final lastActivity = summary.lastActivityAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('book_detail_summary'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('サマリー', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(averageRating == null ? '評価なし' : '★ $averageRating'),
                const SizedBox(width: 8),
                Text('レビュー ${summary.reviewCount}件'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'メモ ${summary.memoCount}件 / 引用 ${summary.quoteCount}件 / お気に入り ${summary.favoriteNoteCount}件'),
            if (lastActivity != null)
              Text(
                '最終活動 ${lastActivity.year}/${lastActivity.month.toString().padLeft(2, '0')}/${lastActivity.day.toString().padLeft(2, '0')}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(Book book) {
    final summary = BookDetailSummary.build(book, _reviews, _notes);
    final children = <Widget>[
      Text('読書進捗', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(summary.progressLabel),
    ];
    switch (book.readingStatus) {
      case ReadingStatus.unread:
        children.add(const SizedBox(height: 8));
        children.add(OutlinedButton.icon(
          key: AppKeys.bookProgressStart,
          onPressed: _startReading,
          icon: const Icon(Icons.play_arrow),
          label: const Text('読書開始'),
        ));
      case ReadingStatus.reading:
        children.add(const SizedBox(height: 8));
        children.add(OutlinedButton.icon(
          key: AppKeys.bookProgressEdit,
          onPressed: _showPageInputDialog,
          icon: const Icon(Icons.menu_book),
          label: const Text('ページ更新'),
        ));
      case ReadingStatus.finished:
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 読書開始を記録して永続化する。
  Future<void> _startReading() async {
    final updated = ReadingStatusService.markStarted(widget.book);
    await widget.bookRepository.updateBook(updated);
    if (!mounted) return;
    setState(() {
      _book = updated;
    });
  }

  /// 現在ページ入力ダイアログを表示する。
  Future<void> _showPageInputDialog() async {
    final controller =
        TextEditingController(text: '${_book?.currentPage ?? 0}');
    final error = ValueNotifier<String?>(null);
    final saved = await showDialog<Book>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('現在ページを入力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: AppKeys.bookProgressInput,
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '現在ページ',
                  errorText: error.value,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: AppKeys.bookProgressSave,
              onPressed: () {
                final page = int.tryParse(controller.text.trim());
                if (page == null) {
                  error.value = '数値で入力してください';
                  return;
                }
                Navigator.of(dialogContext).pop(
                    ReadingStatusService.updateProgress(
                        _book ?? widget.book, page));
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (saved == null || !mounted) return;
    await widget.bookRepository.updateBook(saved);
    if (!mounted) return;
    setState(() {
      _book = saved;
    });
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('book_detail_open_reviews'),
            onPressed: _openReviewScreen,
            icon: const Icon(Icons.rate_review),
            label: const Text('レビューを書く/見る'),
          ),
        ),
        if (widget.noteRepository != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('book_detail_open_notes'),
              onPressed: _openNotesScreen,
              icon: const Icon(Icons.edit_note),
              label: const Text('メモ・引用'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewSection() {
    final reviews = _reviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('レビュー', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (reviews.isEmpty)
          Container(
            key: const Key('book_detail_empty_reviews'),
            padding: const EdgeInsets.all(8),
            child: const Text('レビューはまだありません'),
          )
        else
          ...reviews.map((r) => _ReviewRow(review: r)),
      ],
    );
  }

  Widget _buildNoteSection() {
    final notes = _notes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('メモ・引用', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (notes.isEmpty)
          Container(
            key: const Key('book_detail_empty_notes'),
            padding: const EdgeInsets.all(8),
            child: const Text('メモ・引用はまだありません'),
          )
        else
          ...notes.map((n) => _NoteRow(note: n)),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final Review review;

  const _ReviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('book_detail_review_row_${review.id}'),
      leading: Text('★' * review.rating),
      title: Text(review.text.isEmpty ? '（本文なし）' : review.text),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final BookNote note;

  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final page = note.pageNumber;
    return ListTile(
      key: Key('book_detail_note_row_${note.id}'),
      leading: Text(
        note.isFavorite ? '★ ${note.kind.label}' : note.kind.label,
      ),
      title: Text(note.content),
      subtitle: Text(page == null ? 'ページ未指定' : 'p.$page'),
    );
  }
}
