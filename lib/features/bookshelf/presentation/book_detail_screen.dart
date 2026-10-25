import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/bookshelf/domain/genre_service.dart';
import 'package:book_review_app/features/bookshelf/domain/reading_status_service.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_export_coordinator.dart';
import 'package:book_review_app/features/locations/domain/shelf_location_service.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/book_loan_service.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';
import 'package:book_review_app/features/loan/presentation/loan_edit_dialog.dart';
import 'package:book_review_app/features/loan/presentation/loan_management_screen.dart';
import 'package:book_review_app/features/notes/presentation/book_notes_screen.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

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

  /// 貸出リポジトリ（未指定なら貸出セクションを表示しない）
  final BookLoanRepository? loanRepository;

  /// 現在日時の注入（試練の決定論化用）。未指定なら実時計。
  final DateTime? nowOverride;

  /// 読了イベント書き出しの調整役（未指定なら書き出さない）
  final BookRewardExportCoordinator? rewardExportCoordinator;

  const BookDetailScreen({
    super.key,
    required this.book,
    required this.bookRepository,
    required this.reviewRepository,
    this.noteRepository,
    this.loanRepository,
    this.nowOverride,
    this.rewardExportCoordinator,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  List<Review> _reviews = const [];
  List<BookNote> _notes = const [];
  List<BookLoan> _loans = const [];
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
      if (widget.loanRepository != null)
        widget.loanRepository!.loadLoans()
      else
        Future<List<BookLoan>>.value(const []),
    ]);
    if (!mounted) return;
    setState(() {
      _reviews = results[0] as List<Review>;
      _notes = results[1] as List<BookNote>;
      _loans = results[2] as List<BookLoan>;
      _loading = false;
    });
  }

  /// 貸出の再読込（返却・新規記録の後に呼ぶ）。
  Future<void> _reloadLoans() async {
    final repository = widget.loanRepository;
    if (repository == null) return;
    final loans = await repository.loadLoans();
    if (!mounted) return;
    setState(() => _loans = loans);
  }

  /// この本の未返却貸出（最新の lentAt）。
  BookLoan? get _activeLoan => BookLoanService.activeLoanFor(
        _loans,
        widget.book.id,
      );

  DateTime get _loanNow => widget.nowOverride ?? DateTime.now();

  /// 貸出を記録するダイアログを開き、確定されたら永続化する。
  Future<void> _lendBook() async {
    final repository = widget.loanRepository;
    if (repository == null) return;
    final loan = await LoanEditDialog.show(
      context,
      bookId: widget.book.id,
      lentAt: _loanNow,
    );
    if (loan == null || !mounted) return;
    final current = await repository.loadLoans();
    await repository.saveLoans(BookLoanService.addLoan(current, loan));
    await _reloadLoans();
  }

  /// この本の未返却貸出を返却済みにして永続化する。
  Future<void> _returnLoan(BookLoan loan) async {
    final repository = widget.loanRepository;
    if (repository == null) return;
    final current = await repository.loadLoans();
    await repository.saveLoans(
      BookLoanService.markReturned(current, loan.id, _loanNow),
    );
    await _reloadLoans();
  }

  /// 貸出中一覧画面を開く。
  ///
  /// 返却期限の通知セクションは設定リポジトリと通知スケジューラの
  /// 両方が揃ったときだけ描画されるため、実装をここで注入する
  /// （注入しないと本番で通知設定が永久に出ない）。
  void _openLoanManagement() {
    final repository = widget.loanRepository;
    if (repository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoanManagementScreen(
          repository: repository,
          nowOverride: widget.nowOverride,
          bookTitleLoader: _loadBookTitles,
          reminderRepository: HiveLoanDueReminderRepository(),
          reminderScheduler: NotificationServiceLoanDueReminderScheduler(),
        ),
      ),
    );
  }

  /// bookId → 書名（通知本文と貸出管理の一覧表示に使う）。
  Future<Map<String, String>> _loadBookTitles() async {
    final books = await widget.bookRepository.getBooks();
    return {for (final b in books) b.id: b.title};
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
                const SizedBox(height: 16),
                _buildGenreSection(book),
                const SizedBox(height: 16),
                _buildLocationSection(book),
                if (widget.loanRepository != null) ...[
                  const SizedBox(height: 16),
                  _buildLoanSection(book),
                ],
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
    return SemanticHelper.container(
      testId: 'book_detail_sec_summary',
      label: 'サマリー: ${summary.progressLabel}',
      child: Card(
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
        children.add(SemanticHelper.interactive(
          testId: 'book_detail_btn_start_reading',
          label: '「${book.title}」の読書を開始',
          child: OutlinedButton.icon(
            key: AppKeys.bookProgressStart,
            onPressed: _startReading,
            icon: const Icon(Icons.play_arrow),
            label: const Text('読書開始'),
          ),
        ));
      case ReadingStatus.reading:
        children.add(const SizedBox(height: 8));
        children.add(SemanticHelper.interactive(
          testId: 'book_detail_btn_update_progress',
          label: '「${book.title}」の現在ページを更新',
          child: OutlinedButton.icon(
            key: AppKeys.bookProgressEdit,
            onPressed: _showPageInputDialog,
            icon: const Icon(Icons.menu_book),
            label: const Text('ページ更新'),
          ),
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
              SemanticHelper.textField(
                testId: 'book_detail_txt_current_page',
                label: '現在ページを入力',
                child: TextField(
                  key: AppKeys.bookProgressInput,
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '現在ページ',
                    errorText: error.value,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            SemanticHelper.interactive(
              testId: 'book_detail_btn_save_progress',
              label: '現在ページを保存',
              child: FilledButton(
                key: AppKeys.bookProgressSave,
                onPressed: () {
                  final page = int.tryParse(controller.text.trim());
                  if (page == null) {
                    error.value = '数値で入力してください';
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                      ReadingStatusService.updateProgress(
                          _book ?? widget.book, page,
                          now: widget.nowOverride));
                },
                child: const Text('保存'),
              ),
            ),
          ],
        );
      },
    );
    if (saved == null || !mounted) return;
    // 保存前の本（読了遷移の判定に使う）
    final previous = _book ?? widget.book;
    await widget.bookRepository.updateBook(saved);

    // 読了遷移ならクロスアプリ向けイベントを書き出す。
    // 連携の失敗で蔵書詳細の操作を壊さないよう、ここで握りつぶす。
    final coordinator = widget.rewardExportCoordinator;
    if (coordinator != null) {
      try {
        // リポジトリの一覧は保存前の状態なので、この本だけ保存後へ差し替えて渡す
        //（そのまま渡すと読了冊数が今回の読了を数え落とす）。
        final stored = await widget.bookRepository.getBooks();
        final allBooks = <Book>[
          for (final b in stored) if (b.id == saved.id) saved else b,
        ];
        await coordinator.exportCompletion(
          previous: previous,
          updated: saved,
          allBooks: allBooks,
        );
      } catch (_) {
        // best-effort
      }
    }

    if (!mounted) return;
    setState(() {
      _book = saved;
    });
  }

  /// ジャンルの付与・編集セクション。
  ///
  /// 追加・削除は必ず [BookRepository.updateBook] へ到達させて永続化する。
  Widget _buildGenreSection(Book book) {
    final genres = GenreService.canonicalList(book.genres);
    return Card(
      key: const Key('book_detail_sec_genres'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sell_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  'ジャンル',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  key: AppKeys.genreAdd,
                  onPressed: _showGenreInputDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('ジャンルを追加'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (genres.isEmpty)
              Text(
                'ジャンル未設定',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final genre in genres)
                    Chip(
                      key: AppKeys.genreChip(genre),
                      label: Text(genre),
                      deleteIcon: Icon(
                        Icons.close,
                        size: 16,
                        key: AppKeys.genreRemove(genre),
                      ),
                      deleteButtonTooltipMessage: '削除',
                      onDeleted: () => _removeGenre(genre),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 所在（物理的な置き場所）の表示・編集セクション。
  ///
  /// 編集は必ず [BookRepository.updateBook] へ到達させて永続化する。
  Widget _buildLocationSection(Book book) {
    final location = ShelfLocationService.locationOf(book);
    return Card(
      key: AppKeys.locationSection,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  '所在',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                SemanticHelper.interactive(
                  testId: 'book_detail_btn_edit_location',
                  label: '所在を編集',
                  child: TextButton.icon(
                    key: AppKeys.locationEditButton,
                    onPressed: _showLocationInputDialog,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('所在を編集'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (location == null)
              Text(
                '所在未設定',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Text(location, key: AppKeys.locationValue),
          ],
        ),
      ),
    );
  }

  /// 所在入力ダイアログを開き、確定値を永続化する。
  ///
  /// 検証エラー時はダイアログを閉じずにエラーを表示する。
  /// 「所在を消す」は空文字を返し、所在地を null に戻す。
  Future<void> _showLocationInputDialog() async {
    final current = _book ?? widget.book;
    final existing = ShelfLocationService.locationOf(current);
    final controller = TextEditingController(text: existing ?? '');
    String? error;

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('所在を編集'),
          content: SemanticHelper.textField(
            testId: 'book_detail_txt_location',
            label: '所在',
            child: TextField(
              key: AppKeys.locationInput,
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '所在',
                hintText: '例: 居間の本棚 2段目',
                errorText: error,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('やめる'),
            ),
            if (existing != null)
              TextButton(
                key: AppKeys.locationClear,
                onPressed: () => Navigator.of(dialogContext).pop(''),
                child: const Text('所在を消す'),
              ),
            SemanticHelper.interactive(
              testId: 'book_detail_btn_save_location',
              label: '所在を保存',
              child: TextButton(
                key: AppKeys.locationSave,
                onPressed: () {
                  final message =
                      ShelfLocationService.validateNew(controller.text);
                  if (message != null) {
                    setDialogState(() => error = message);
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    ShelfLocationService.normalize(controller.text),
                  );
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );

    if (value == null || !mounted) return;
    await _persistLocation(value);
  }

  /// 所在を永続化して画面へ反映する（空文字は null に戻す）。
  Future<void> _persistLocation(String value) async {
    final current = _book ?? widget.book;
    final updated = current.copyWith(
      location: value,
      clearLocation: value.isEmpty,
    );
    await widget.bookRepository.updateBook(updated);
    if (!mounted) return;
    setState(() => _book = updated);
  }

  /// 貸出セクション（ListView 最下部・loanRepository 非null のときのみ）。
  ///
  /// 未返却の貸出があれば借り手と期限を、無ければ記録導線を出す。
  Widget _buildLoanSection(Book book) {
    final active = _activeLoan;
    final now = _loanNow;
    return Card(
      key: AppKeys.loanDetailSection,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book_outlined, size: 18),
                const SizedBox(width: 6),
                Text('貸出', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            if (active != null) ...[
              Text(
                '${active.borrower} / ${BookLoanService.dueLabel(active, now: now)}',
                key: AppKeys.loanDetailStatusLabel,
              ),
              const SizedBox(height: 4),
              SemanticHelper.interactive(
                testId: 'book_detail_btn_return_loan',
                label: '「${active.borrower}」への貸出を返却済みにする',
                child: OutlinedButton.icon(
                  key: AppKeys.loanReturnButton(active.id),
                  onPressed: () => _returnLoan(active),
                  icon: const Icon(Icons.assignment_turned_in_outlined,
                      size: 18),
                  label: const Text('返却'),
                ),
              ),
            ] else
              SemanticHelper.interactive(
                testId: 'book_detail_btn_lend',
                label: '「${book.title}」の貸出を記録',
                child: FilledButton.icon(
                  key: AppKeys.loanLendButton,
                  onPressed: _lendBook,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('貸出を記録'),
                ),
              ),
            const SizedBox(height: 8),
            SemanticHelper.interactive(
              testId: 'book_detail_btn_loan_management',
              label: '貸出中一覧を開く',
              child: TextButton.icon(
                key: AppKeys.loanEntryButton,
                onPressed: _openLoanManagement,
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('貸出中一覧を開く'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ジャンル一覧を永続化して画面へ反映する。
  Future<void> _persistGenres(List<String> genres) async {
    final current = _book ?? widget.book;
    final canonical = GenreService.canonicalList(genres);
    final updated = canonical.isEmpty
        ? current.copyWith(clearGenres: true)
        : current.copyWith(genres: canonical);
    await widget.bookRepository.updateBook(updated);
    if (!mounted) return;
    setState(() => _book = updated);
  }

  /// 指定ジャンルを蔵書から取り除く。
  Future<void> _removeGenre(String genre) async {
    final current = _book ?? widget.book;
    final next = GenreService.canonicalList(current.genres)
        .where((g) => g != genre)
        .toList(growable: false);
    await _persistGenres(next);
  }

  /// ジャンル入力ダイアログを開き、検証を通過したら追加する。
  Future<void> _showGenreInputDialog() async {
    final current = _book ?? widget.book;
    final existing = GenreService.canonicalList(current.genres);
    final controller = TextEditingController();
    String? error;

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          key: AppKeys.genreDialog,
          title: const Text('ジャンルを追加'),
          content: TextField(
            key: AppKeys.genreInput,
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'ジャンル名',
              hintText: '小説・技術書 など',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('やめる'),
            ),
            TextButton(
              key: AppKeys.genreSave,
              onPressed: () {
                final message =
                    GenreService.validateNew(existing, controller.text);
                if (message != null) {
                  setDialogState(() => error = message);
                  return;
                }
                Navigator.of(dialogContext)
                    .pop(GenreService.normalize(controller.text));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (value == null || value.isEmpty) return;
    await _persistGenres([...existing, value]);
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SemanticHelper.interactive(
            testId: 'book_detail_btn_open_reviews',
            label: '「${(_book ?? widget.book).title}」のレビューを書く/見る',
            child: OutlinedButton.icon(
              key: const Key('book_detail_open_reviews'),
              onPressed: _openReviewScreen,
              icon: const Icon(Icons.rate_review),
              label: const Text('レビューを書く/見る'),
            ),
          ),
        ),
        if (widget.noteRepository != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SemanticHelper.interactive(
              testId: 'book_detail_btn_open_notes',
              label: '「${(_book ?? widget.book).title}」のメモ・引用を開く',
              child: OutlinedButton.icon(
                key: const Key('book_detail_open_notes'),
                onPressed: _openNotesScreen,
                icon: const Icon(Icons.edit_note),
                label: const Text('メモ・引用'),
              ),
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
