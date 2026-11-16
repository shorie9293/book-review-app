import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_deletion_service.dart';
import 'package:book_review_app/features/bookshelf/data/book_restore_service.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/bookshelf/domain/book_deletion.dart';
import 'package:book_review_app/features/bookshelf/domain/book_restore.dart';
import 'package:book_review_app/features/bookshelf/domain/genre_service.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:book_review_app/features/bookshelf/domain/reading_status_service.dart';
import 'package:book_review_app/features/backup/data/backup_csv_sharer.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/data/hive_orphan_scan_loader.dart';
import 'package:book_review_app/features/backup/presentation/backup_screen.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_export_coordinator.dart';
import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/barcode_scanner_screen.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';
import 'package:book_review_app/features/bookshelf/domain/app_bar_action_plan.dart';
import 'package:book_review_app/features/bookshelf/presentation/library_filter_bar.dart';
import 'package:book_review_app/features/bookshelf/presentation/stagnant_books_screen.dart';
import 'package:book_review_app/features/duplicates/domain/duplicate_book_service.dart';
import 'package:book_review_app/features/duplicates/presentation/duplicate_books_screen.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_resync.dart';
import 'package:book_review_app/features/locations/domain/shelf_location_service.dart';
import 'package:book_review_app/features/challenge/presentation/challenge_screen.dart';
import 'package:book_review_app/features/goals/presentation/daily_reading_goal_screen.dart';
import 'package:book_review_app/features/import/presentation/bulk_import_screen.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/domain/repositories/reading_queue_repository.dart';
import 'package:book_review_app/features/queue/presentation/reading_queue_screen.dart';
import 'package:book_review_app/features/notes/presentation/favorite_notes_screen.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';
import 'package:book_review_app/features/recommendation/presentation/recommendation_screen.dart';
import 'package:book_review_app/features/reminder/infrastructure/hive_quiet_hours_repository.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_permission_requester.dart';
import 'package:book_review_app/features/reminder/presentation/reading_reminder_settings_screen.dart';
import 'package:book_review_app/features/review/presentation/review_search_screen.dart';
import 'package:book_review_app/screens/text_scale_settings_screen.dart';
import 'package:book_review_app/screens/theme_mode_settings_screen.dart';
import 'package:book_review_app/screens/reduce_motion_settings_screen.dart';
import 'package:book_review_app/core/haptics.dart';
import 'package:book_review_app/core/infrastructure/app_lock_settings_screen.dart';
import 'package:book_review_app/features/about/presentation/about_screen.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/widgets/empty_state.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/features/undo/domain/undo_buffer.dart';
import 'package:book_review_app/features/undo/presentation/undo_snack_bar.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class BookshelfScreen extends StatefulWidget {
  final BookRepository repository;
  final BookSearchService? searchService;
  final List<Book> initialBooks;
  final ReviewRepository? reviewRepository;

  /// 「お気に入りの引用」画面のリポジトリ（未指定なら導線を表示しない）
  final BookNoteRepository? noteRepository;

  /// 「次に読む」キューのリポジトリ（未指定なら導線を表示しない）
  final ReadingQueueRepository? queueRepository;

  /// 貸出のリポジトリ（未指定なら蔵書詳細に貸出セクションを表示しない）
  final BookLoanRepository? loanRepository;

  /// 読書時間画面のリポジトリ（未指定なら Hive 実装を使う・試練用差し替え口）
  final ReadingSessionRepository? readingSessionRepositoryOverride;

  /// レビュー横断検索画面のビルダー（未指定なら既定の [ReviewSearchScreen] を表示）
  final WidgetBuilder? reviewSearchBuilder;

  /// クロスアプリ連携の userId 保管庫（未指定ならバックアップ画面に導線を出さない）
  final CrossAppLinkRepository? crossAppLinkRepository;

  /// クロスアプリ連携の送信済みイベント記録（バックアップ画面へ渡すだけ）
  final RewardExportLogRepository? crossAppRewardLogRepository;

  /// 読了イベント書き出しの調整役（未指定なら書き出さない）
  final BookRewardExportCoordinator? rewardExportCoordinator;

  /// 返却期限リマインダーの再計算窓口（蔵書詳細へ引き渡すだけ）
  final LoanDueReminderResync? reminderResync;

  /// 現在の文字サイズ倍率（設定画面へ渡す）
  final double textScale;

  /// 文字サイズ変更時のコールバック
  final ValueChanged<double>? onScaleChanged;

  /// 現在のテーマ設定（設定画面へ渡す）
  final ThemeModeSetting themeMode;

  /// テーマ変更時のコールバック
  final ValueChanged<ThemeModeSetting>? onThemeModeChanged;

  /// 現在の「動きを減らす」設定（設定画面へ渡す）
  final ReduceMotionSetting reduceMotion;

  /// 「動きを減らす」設定の変更コールバック
  final ValueChanged<ReduceMotionSetting>? onReduceMotionChanged;

  const BookshelfScreen({
    super.key,
    required this.repository,
    this.searchService,
    this.initialBooks = const [],
    this.reviewRepository,
    this.noteRepository,
    this.queueRepository,
    this.loanRepository,
    this.readingSessionRepositoryOverride,
    this.reviewSearchBuilder,
    this.crossAppLinkRepository,
    this.crossAppRewardLogRepository,
    this.rewardExportCoordinator,
    this.reminderResync,
    this.textScale = 1.0,
    this.onScaleChanged,
    this.themeMode = ThemeModeSetting.system,
    this.onThemeModeChanged,
    this.reduceMotion = ReduceMotionSetting.system,
    this.onReduceMotionChanged,
  });

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  final TextEditingController _isbnController = TextEditingController();
  final BookSearchService _searchService = BookSearchService();
  late List<Book> _books;
  LibraryQuery _query = const LibraryQuery();
  Book? _foundBook;
  bool _isSearching = false;
  String? _errorMessage;

  /// 直近の蔵書削除の復元材料（Undo は1回限り）
  final UndoBuffer<BookRestoreSnapshot> _undoBuffer =
      UndoBuffer<BookRestoreSnapshot>();

  @override
  void initState() {
    super.initState();
    _books = List<Book>.from(widget.initialBooks);
  }

  @override
  void dispose() {
    _isbnController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    final books = await widget.repository.getBooks();
    if (mounted) {
      setState(() {
        _books = books;
      });
    }
  }

  Future<void> _searchByIsbn() async {
    final isbn = _isbnController.text.trim();
    if (isbn.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundBook = null;
      _errorMessage = null;
    });

    try {
      final service = widget.searchService ?? _searchService;
      final book = await service.searchByIsbn(isbn);
      if (mounted) {
        setState(() {
          _foundBook = book;
          _isSearching = false;
          if (book == null) {
            _errorMessage = '書籍が見つかりませんでした';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = '検索中にエラーが発生しました: $e';
        });
      }
    }
  }

  Future<void> _addBookToShelf(Book book) async {
    // 同一ISBNの蔵書が既にある場合は重複登録しない（重複整理画面へ誘導）。
    final isbnKey = DuplicateBookService.normalizeIsbn(book.isbn);
    if (isbnKey.isNotEmpty &&
        _books.any(
          (existing) =>
              DuplicateBookService.normalizeIsbn(existing.isbn) == isbnKey,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${book.title}」は既に本棚に登録されています')),
      );
      return;
    }

    final uuid = _generateUuid();
    final newBook = Book(
      id: uuid,
      title: book.title,
      author: book.author,
      isbn: book.isbn,
      coverImageUrl: book.coverImageUrl,
      publisher: book.publisher,
      publishedDate: book.publishedDate,
      pageCount: book.pageCount,
      description: book.description,
    );

    await widget.repository.addBook(newBook);
    await _loadBooks();
    // 蔵書の保存確定を触覚で伝える。
    hapticTap();

    if (mounted) {
      setState(() {
        _foundBook = null;
        _isbnController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${book.title}」を本棚に追加しました')),
        );
      });
    }
  }

  String _generateUuid() {
    // Simple UUID v4-like generation
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = (timestamp * 37 + 17) % 0xFFFFFFFF;
    return '$timestamp-$random-${_books.length + 1}';
  }

  void _openStagnantBooks() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StagnantBooksScreen(books: List.of(_books)),
      ),
    );
  }

  /// 「読書の推薦」画面を開く。
  void _openRecommendations() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecommendationScreen(books: List.of(_books)),
      ),
    );
  }

  Future<void> _openBarcodeScanner() async {
    final service = widget.searchService ?? _searchService;
    final scannedBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(searchService: service),
      ),
    );
    if (scannedBook != null && mounted) {
      await _addBookToShelf(scannedBook);
    }
  }

  Future<void> _openBulkImport() async {
    final service = widget.searchService ?? _searchService;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BulkImportScreen(
          repository: widget.repository,
          searchService: service,
          onImported: _loadBooks,
        ),
      ),
    );
  }

  /// 「次に読む」キュー画面を開く。
  Future<void> _openReadingQueue() async {
    final queueRepository = widget.queueRepository;
    if (queueRepository == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadingQueueScreen(
          repository: queueRepository,
          booksLoader: widget.repository.getBooks,
        ),
      ),
    );
    // キューの並び替え・読了状態の変化を本棚へ反映する
    await _loadBooks();
  }

  /// お気に入りの引用画面を開く。
  Future<void> _openFavoriteNotes() async {
    final noteRepository = widget.noteRepository;
    if (noteRepository == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FavoriteNotesScreen(
          repository: noteRepository,
          books: _books,
        ),
      ),
    );
  }

  /// エクスポート／バックアップ画面を開く。
  Future<void> _openBackup() async {
    final reviewRepository = widget.reviewRepository;
    final noteRepository = widget.noteRepository;
    final orphanCleanupService =
        reviewRepository == null || noteRepository == null
            ? null
            : BookDeletionService(
                deleteReviewById: (id) => reviewRepository.deleteReview(id),
                deleteNoteById: (id) => noteRepository.deleteNote(id),
              );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BackupScreen(
          repository: HiveBackupRepository(
            bookRepository: widget.repository,
            reviewRepository: widget.reviewRepository!,
            noteRepository: widget.noteRepository!,
          ),
          crossAppLinkRepository: widget.crossAppLinkRepository,
          crossAppRewardLogRepository: widget.crossAppRewardLogRepository,
          csvSharer: const SharePlusBackupCsvSharer(),
          allReviewsLoader: loadAllReviewsFromHive,
          orphanCleanupService: orphanCleanupService,
        ),
      ),
    );
  }

  /// 文字サイズ設定画面を開く。
  Future<void> _openTextScaleSettings() async {
    final onScaleChanged = widget.onScaleChanged;
    if (onScaleChanged == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextScaleSettingsScreen(
          currentScale: widget.textScale,
          onScaleChanged: onScaleChanged,
        ),
      ),
    );
  }

  /// テーマ設定画面を開く。
  Future<void> _openThemeModeSettings() async {
    final onThemeModeChanged = widget.onThemeModeChanged;
    if (onThemeModeChanged == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThemeModeSettingsScreen(
          currentMode: widget.themeMode,
          onModeChanged: onThemeModeChanged,
        ),
      ),
    );
  }

  /// アプリロック設定画面を開く。
  Future<void> _openAppLockSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AppLockSettingsScreen(),
      ),
    );
  }

  /// 「動きを減らす」設定画面を開く。
  Future<void> _openReduceMotionSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReduceMotionSettingsScreen(
          initial: widget.reduceMotion,
          onChanged: widget.onReduceMotionChanged,
        ),
      ),
    );
  }

  /// AppBar の導線を「直置き」と「その他メニュー」へ振り分けて描画する。
  ///
  /// 実機幅360dpでは17件のアイコンが `RenderFlex overflowed` を起こし、
  /// 右端の操作に到達できなかった。幅と文字倍率から直置きできる件数を決め、
  /// 収まらない分は「その他」メニューへ畳む（広い画面では従来通り全件直置き）。
  /// 各導線の Key・意味・遷移先は畳んでも不変。
  List<Widget> _buildAppBarActionWidgets(BuildContext context) {
    final actions = _shelfActions();
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 3.0);
    final plan = AppBarActionPlan.plan(
      actionCount: actions.length,
      availableWidth: MediaQuery.sizeOf(context).width,
      titleReserve: kAppBarTitleReserveBase * textScale,
    );
    // 優先度の高い導線を直置きし、残りは宣言順で「その他」へ。
    final ordered = List<_ShelfAction>.of(actions)
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        return byPriority != 0 ? byPriority : a.index.compareTo(b.index);
      });
    final inline = ordered.take(plan.inlineCount).toList(growable: false);
    final inlineKeys = inline.map((action) => action.key).toSet();
    final overflow = actions
        .where((action) => !inlineKeys.contains(action.key))
        .toList(growable: false);

    return [
      for (final action in inline) _inlineAppBarAction(action),
      if (overflow.isNotEmpty) _moreAppBarActions(overflow),
    ];
  }

  Widget _inlineAppBarAction(_ShelfAction action) {
    final button = IconButton(
      key: action.key,
      icon: Icon(action.icon),
      tooltip: action.tooltip,
      onPressed: action.onPressed,
    );
    final testId = action.semanticTestId;
    if (testId == null) return button;
    return SemanticHelper.interactive(
      testId: testId,
      label: action.semanticLabel ?? action.tooltip,
      child: button,
    );
  }

  Widget _moreAppBarActions(List<_ShelfAction> overflow) {
    return SemanticHelper.interactive(
      testId: 'bookshelf_btn_more_actions',
      label: 'その他の操作を開く',
      child: PopupMenuButton<Key>(
        key: AppKeys.bookshelfMoreActions,
        icon: const Icon(Icons.more_vert),
        tooltip: 'その他',
        onSelected: (key) {
          for (final action in overflow) {
            if (action.key == key) {
              action.onPressed();
              return;
            }
          }
        },
        itemBuilder: (context) => [
          for (final action in overflow)
            PopupMenuItem<Key>(
              key: action.key,
              value: action.key,
              child: Row(
                children: [
                  Icon(action.icon, size: 20),
                  const SizedBox(width: 12),
                  Flexible(child: Text(action.tooltip)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// AppBar に並べる導線の定義（宣言順＝「その他」メニュー内の並び順）。
  ///
  /// [priority] は直置きの優先度（小さいほど優先）。狭幅でも
  /// 蔵書の追加（バーコード）と読書時間の計測は必ず直置きに残す。
  List<_ShelfAction> _shelfActions() {
    return [
      _ShelfAction(
        index: 0,
        priority: 2,
        key: const Key('stats_button'),
        icon: Icons.bar_chart,
        tooltip: '読書統計',
        semanticTestId: 'bookshelf_btn_stats',
        semanticLabel: '読書統計を開く',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const StatsScreen(),
            ),
          );
        },
      ),
      _ShelfAction(
        index: 1,
        priority: 10,
        key: const Key('recommendation_button'),
        icon: Icons.auto_awesome,
        tooltip: '読書の推薦',
        semanticTestId: 'bookshelf_btn_recommendation',
        semanticLabel: '読書の推薦を開く',
        onPressed: _openRecommendations,
      ),
      _ShelfAction(
        index: 2,
        priority: 10,
        key: const Key('stagnant_books_button'),
        icon: Icons.hourglass_bottom,
        tooltip: '停滞している本',
        semanticTestId: 'bookshelf_btn_stagnant_books',
        semanticLabel: '停滞している本を開く',
        onPressed: _openStagnantBooks,
      ),
      _ShelfAction(
        index: 3,
        priority: 10,
        key: const Key('challenge_button'),
        icon: Icons.emoji_events,
        tooltip: '年間読書チャレンジ',
        semanticTestId: 'bookshelf_btn_challenge',
        semanticLabel: '年間読書チャレンジを開く',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ChallengeScreen(),
            ),
          );
        },
      ),
      _ShelfAction(
        index: 4,
        priority: 0,
        key: const Key('scan_barcode_button'),
        icon: Icons.camera_alt,
        tooltip: 'バーコードスキャン',
        semanticTestId: 'bookshelf_btn_scan_barcode',
        semanticLabel: 'バーコードスキャンを開く',
        onPressed: _openBarcodeScanner,
      ),
      _ShelfAction(
        index: 5,
        priority: 10,
        key: const Key('bulk_import_button'),
        icon: Icons.library_add,
        tooltip: '一括インポート',
        semanticTestId: 'bookshelf_btn_bulk_import',
        semanticLabel: '一括インポートを開く',
        onPressed: _openBulkImport,
      ),
      if (widget.queueRepository != null)
        _ShelfAction(
          index: 6,
          priority: 10,
          key: const Key('reading_queue_button'),
          icon: Icons.playlist_play,
          tooltip: '次に読む',
          semanticTestId: 'bookshelf_btn_reading_queue',
          semanticLabel: '次に読むキューを開く',
          onPressed: _openReadingQueue,
        ),
      if (widget.noteRepository != null)
        _ShelfAction(
          index: 7,
          priority: 10,
          key: const Key('open_favorites_button'),
          icon: Icons.star_outline,
          tooltip: 'お気に入りの引用',
          semanticTestId: 'bookshelf_btn_open_favorites',
          semanticLabel: 'お気に入りの引用を開く',
          onPressed: _openFavoriteNotes,
        ),
      if (widget.reviewRepository != null && widget.noteRepository != null)
        _ShelfAction(
          index: 8,
          priority: 10,
          key: const Key('backup_button'),
          icon: Icons.upload_file,
          tooltip: 'エクスポート/バックアップ',
          semanticTestId: 'bookshelf_btn_backup',
          semanticLabel: 'エクスポート/バックアップを開く',
          onPressed: _openBackup,
        ),
      if (widget.onScaleChanged != null)
        _ShelfAction(
          index: 9,
          priority: 10,
          key: const Key('text_scale_settings_button'),
          icon: Icons.format_size,
          tooltip: '文字サイズ設定',
          semanticTestId: 'bookshelf_btn_text_scale_settings',
          semanticLabel: '文字サイズ設定を開く',
          onPressed: _openTextScaleSettings,
        ),
      if (widget.onThemeModeChanged != null)
        _ShelfAction(
          index: 10,
          priority: 10,
          key: AppKeys.themeModeEntry,
          icon: Icons.brightness_6,
          tooltip: 'テーマ設定',
          semanticTestId: 'bookshelf_btn_theme_mode_settings',
          semanticLabel: 'テーマ設定を開く',
          onPressed: _openThemeModeSettings,
        ),
      if (widget.onReduceMotionChanged != null)
        _ShelfAction(
          index: 11,
          priority: 10,
          key: AppKeys.reduceMotionEntry,
          icon: Icons.motion_photos_off_outlined,
          tooltip: '動きを減らす',
          semanticTestId: 'bookshelf_btn_reduce_motion_settings',
          semanticLabel: '動きを減らす設定を開く',
          onPressed: _openReduceMotionSettings,
        ),
      _ShelfAction(
        index: 12,
        priority: 10,
        key: AppKeys.appLockEntry,
        icon: Icons.lock_outline,
        tooltip: 'アプリロック',
        semanticTestId: 'bookshelf_btn_app_lock',
        semanticLabel: 'アプリロック設定を開く',
        onPressed: _openAppLockSettings,
      ),
      _ShelfAction(
        index: 13,
        priority: 10,
        key: AppKeys.readingReminderEntry,
        icon: Icons.notifications_active,
        tooltip: '読書リマインダー',
        semanticTestId: 'bookshelf_btn_reading_reminder',
        semanticLabel: '読書リマインダーの設定を開く',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReadingReminderSettingsScreen(
              // 静穏時間（おやすみモード）への導線を出すため本番実装を注入。
              quietHoursRepository: HiveQuietHoursRepository(),
              // 通知権限の要求（Android 13+ は要求しないと通知が出ない）。
              permissionRequester: PlatformNotificationPermissionRequester(),
            ),
          ),
        ),
      ),
      _ShelfAction(
        index: 14,
        priority: 10,
        key: const Key('about_entry'),
        icon: Icons.info_outline,
        tooltip: 'アプリについて',
        semanticTestId: 'bookshelf_btn_about',
        semanticLabel: 'アプリについてを開く',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AboutScreen(),
          ),
        ),
      ),
      _ShelfAction(
        index: 15,
        priority: 10,
        key: AppKeys.dailyGoalEntry,
        icon: Icons.flag_outlined,
        tooltip: '読書の日次目標',
        semanticTestId: 'bookshelf_btn_daily_goal',
        semanticLabel: '読書の日次目標を開く',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DailyReadingGoalScreen(),
          ),
        ),
      ),
      _ShelfAction(
        index: 16,
        priority: 1,
        key: AppKeys.readingTimerButton,
        icon: Icons.timer_outlined,
        tooltip: '読書時間',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReadingSessionScreen(
              repository: widget.readingSessionRepositoryOverride ??
                  HiveReadingSessionRepository(),
              now: DateTime.now,
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_bookshelf'),
      appBar: AppBar(
        title: const Text('本棚'),
        actions: _buildAppBarActionWidgets(context),
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          Divider(),
          if (DuplicateBookService.findGroups(_books).isNotEmpty)
            _buildDuplicateBanner(),
          LibraryFilterBar(
            query: _query,
            totalCount: _books.length,
            filteredCount: _visibleBooks.length,
            genres: GenreService.availableGenres(_books),
            genreCounts: GenreService.countByGenre(_books),
            locations: ShelfLocationService.availableLocations(_books),
            locationCounts: ShelfLocationService.countByLocation(_books),
            onChanged: (query) => setState(() => _query = query),
          ),
          Expanded(child: _buildBookList()),
        ],
      ),
    );
  }

  /// 検索・絞り込み・並び替えを適用した表示用リスト。
  List<Book> get _visibleBooks => LibraryQueryService.apply(_books, _query);

  /// 重複した蔵書の整理画面を開く。
  Future<void> _openDuplicateBooks() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DuplicateBooksScreen(
          repository: widget.repository,
          noteRepository: widget.noteRepository,
          reviewRepository: widget.reviewRepository,
        ),
      ),
    );
    await _loadBooks();
  }

  /// 重複蔵書のバナー（_books から毎 build 再計算する）。
  Widget _buildDuplicateBanner() {
    final groups = DuplicateBookService.findGroups(_books);
    return Material(
      key: AppKeys.duplicateBanner,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.library_books_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(DuplicateBookService.summaryLabel(groups))),
            TextButton(
              key: AppKeys.duplicateOpenButton,
              onPressed: _openDuplicateBooks,
              child: const Text('整理する'),
            ),
          ],
        ),
      ),
    );
  }

  void _openReviewSearch() {
    final builder = widget.reviewSearchBuilder;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            builder?.call(context) ??
            ReviewSearchScreen(
              bookRepository: widget.repository,
              reviewRepository: widget.reviewRepository!,
            ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // レビュー横断検索への導線。広い画面ではISBN検索行と同一行に並べ、
          // 狭い画面ではISBN入力欄の幅を確保するため直下に縦積みする。
          LayoutBuilder(
            builder: (context, constraints) {
              Widget searchRow({Widget? trailing}) {
                return Row(
                  children: [
                    Expanded(
                      child: SemanticHelper.textField(
                        testId: 'bookshelf_txt_isbn_search',
                        label: 'ISBNで検索',
                        child: TextField(
                          key: const Key('isbn_search_field'),
                          controller: _isbnController,
                          decoration: const InputDecoration(
                            labelText: 'ISBNで検索',
                            hintText: '978-4-7741-8907-9',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SemanticHelper.interactive(
                      testId: 'bookshelf_btn_isbn_search',
                      label: 'ISBNで書籍を検索',
                      child: ElevatedButton(
                        key: const Key('isbn_search_button'),
                        onPressed: _isSearching ? null : _searchByIsbn,
                        child: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('検索'),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing,
                    ],
                  ],
                );
              }

              // 後方互換: レビューリポジトリ未指定なら導線を出さない
              if (widget.reviewRepository == null) return searchRow();

              final reviewButton = SemanticHelper.interactive(
                testId: 'review_search_open_button',
                label: 'レビューを検索',
                child: OutlinedButton.icon(
                  key: AppKeys.reviewSearchOpenButton,
                  onPressed: _openReviewSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('レビューを検索'),
                ),
              );

              if (constraints.maxWidth >= 520) {
                return searchRow(trailing: reviewButton);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchRow(),
                  const SizedBox(height: 8),
                  reviewButton,
                ],
              );
            },
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          if (_foundBook != null) _buildFoundBookCard(_foundBook!),
        ],
      ),
    );
  }

  Widget _buildFoundBookCard(Book book) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  book.coverImageUrl!,
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[200],
                    child: const Icon(Icons.book, size: 40),
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 90,
                color: Colors.grey[200],
                child: const Icon(Icons.book, size: 40),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(book.author, style: TextStyle(color: Colors.grey[600])),
                  if (book.publisher != null)
                    Text(book.publisher!,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(height: 8),
                  SemanticHelper.interactive(
                    testId: 'bookshelf_btn_add_found_book',
                    label: '「${book.title}」を本棚に追加',
                    child: ElevatedButton.icon(
                      onPressed: () => _addBookToShelf(book),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('本棚に追加'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList() {
    final visibleBooks = _visibleBooks;
    if (_books.isEmpty) {
      // 空状態の共通部品。既存文言（📚 蔵書がありません）は一字も変えない。
      return EmptyStateView(
        key: const Key('bookshelf_empty_state'),
        icon: Icons.menu_book_outlined,
        spec: EmptyStateSpec(
          title: '📚 蔵書がありません',
          description: 'バーコードを読み取るか、ISBNで検索して本を追加しましょう。',
          actionLabel: '本を追加',
          onAction: () => _openBarcodeScanner(),
        ),
      );
    }
    if (visibleBooks.isEmpty) {
      return const Center(child: Text('🔍 該当する本がありません'));
    }

    return ListView.builder(
        itemCount: visibleBooks.length,
        itemBuilder: (context, index) {
          final book = visibleBooks[index];
          return SemanticHelper.interactive(
          testId: SemanticHelper.createTestId('bookshelf_book_tile', book.id),
            label: '書籍「${book.title}」を開く',
            child: ListTile(
            leading:
                book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      book.coverImageUrl!,
                      width: 40,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.book),
                    ),
                  )
                : const Icon(Icons.book, size: 40),
            title: Text(book.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${book.author}  |  ${book.isbn}'),
                const SizedBox(height: 4),
                _readingStatusChip(book),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('status_button_${book.id}'),
                  icon: _statusIcon(book.readingStatus),
                  tooltip: '読書状態を変更',
                  onPressed: () => _showReadingStatusDialog(book),
                ),
                SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      'bookshelf_btn_delete_book', book.id),
                  label: '書籍「${book.title}」を本棚から削除',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmAndDeleteBook(book),
                  ),
                ),
              ],
            ),
            onTap: () => _navigateToReviews(book),
            ),
          );
        },
    );
  }

  /// 書籍を本棚から削除する（確認ダイアログ→添付データの連鎖削除）。
  ///
  /// 添付（レビュー・メモ）の取得が失敗しても削除導線は止めない
  /// （空リストへフォールバックし、警告文なしで確認へ進む）。
  Future<void> _confirmAndDeleteBook(Book book) async {
    final reviewRepository = widget.reviewRepository;
    final noteRepository = widget.noteRepository;

    var reviews = <Review>[];
    if (reviewRepository != null) {
      try {
        reviews = await reviewRepository.getReviewsByBookId(book.id);
      } catch (_) {
        reviews = <Review>[];
      }
    }
    var notes = <BookNote>[];
    if (noteRepository != null) {
      try {
        notes = await noteRepository.getNotesByBookId(book.id);
      } catch (_) {
        notes = <BookNote>[];
      }
    }

    final plan = BookDeletionPlan.build(
      bookId: book.id,
      reviews: reviews,
      notes: notes,
    );
    if (!mounted) return;

    final warning = plan.warningSuffix;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('書籍の削除'),
        content: Text(
          warning == null
              ? '書籍「${book.title}」を本棚から削除しますか？'
              : '書籍「${book.title}」を本棚から削除しますか？\n$warning',
        ),
        actions: [
          TextButton(
            key: const Key('book_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: const Key('book_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 削除**前**に、消える実体（本・レビュー・メモ）をそのまま退避する。
    // 取得済みのリストを使うため追加の読み込みは発生しない。
    // 退避に失敗した場合は Undo 導線を出さず、削除だけは続行する。
    BookRestoreSnapshot? snapshot;
    try {
      snapshot = BookRestoreSnapshot.capture(
        book: book,
        reviews: reviews,
        notes: notes,
      );
    } catch (_) {
      snapshot = null;
    }

    final service = BookDeletionService(
      deleteReviews: reviewRepository == null
          ? null
          : (reviewIds) async {
              for (final id in reviewIds) {
                await reviewRepository.deleteReview(id);
              }
            },
      deleteNotesByBookId: noteRepository == null
          ? null
          : (bookId) => noteRepository.deleteNotesByBookId(bookId),
      deleteBook: (bookId) => widget.repository.removeBook(bookId),
    );
    await service.deleteBookWithAttachments(
      bookId: book.id,
      plan: plan,
      reviewIds: [for (final review in reviews) review.id],
    );
    await _loadBooks();

    if (snapshot == null) return;
    _undoBuffer.push(snapshot);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: '「${book.title}」を削除しました',
      onUndo: _undoBookDeletion,
    );
  }

  /// 直近の蔵書削除を逆順（book → notes → reviews）に復元する。
  ///
  /// 復元は専用 zone に隔離し、呼出元（Flutter のエラー報告経路）を汚さない。
  /// 結果は非ブロッキングの SnackBar で1回だけ通知する（UI は止めない）。
  Future<void> _undoBookDeletion() async {
    final snapshot = _undoBuffer.take();
    if (snapshot == null) return;

    final report = await BookRestoreService(
      addBook: widget.repository.addBook,
      addNote: widget.noteRepository?.addNote,
      addReview: widget.reviewRepository?.addReview,
    ).restoreInIsolatedZone(snapshot);

    if (!mounted) return;
    await _loadBooks();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_restoreResultMessage(report)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 復元結果の通知文言（何件戻した／失敗ステップ）
  String _restoreResultMessage(BookRestoreReport report) {
    final counts = '本${report.bookRestored ? 1 : 0}冊・'
        '書評${report.restoredReviews}件・メモ${report.restoredNotes}件';
    if (!report.hasFailures) {
      return '元に戻しました（$counts）';
    }
    return '一部を元に戻せませんでした（$counts を復元／'
        '失敗: ${report.failures.join(", ")}）';
  }

  void _navigateToReviews(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(
          book: book,
          bookRepository: widget.repository,
          reviewRepository: widget.reviewRepository!,
          noteRepository: widget.noteRepository,
          loanRepository: widget.loanRepository,
          rewardExportCoordinator: widget.rewardExportCoordinator,
          reminderResync: widget.reminderResync,
        ),
      ),
    );
  }

  /// 読書状態を更新し保存する
  Future<void> _updateReadingStatus(Book book, Book updated) async {
    await widget.repository.updateBook(updated);

    // 読了遷移ならクロスアプリ向けイベントを書き出す。
    // 連携の失敗で本棚の操作を壊さないよう、ここで握りつぶす。
    final coordinator = widget.rewardExportCoordinator;
    if (coordinator != null) {
      try {
        // 画面上の一覧は更新前の状態なので、この本だけ更新後へ差し替えて渡す
        // （そのまま渡すと読了冊数が今回の読了を数え落とす）。
        final allBooks = <Book>[
          for (final b in _books)
            if (b.id == updated.id) updated else b,
        ];
        await coordinator.exportCompletion(
          previous: book,
          updated: updated,
          allBooks: allBooks,
        );
      } catch (_) {
        // best-effort
      }
    }

    await _loadBooks();
  }

  /// 読書状態変更ダイアログを表示する
  Future<void> _showReadingStatusDialog(Book book) async {
    final result = await showDialog<ReadingStatus>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('「${book.title}」の読書状態'),
        children: [
          for (final status in ReadingStatus.values)
            SimpleDialogOption(
              key: Key('status_option_${status.name}'),
              onPressed: () => Navigator.of(context).pop(status),
              child: SemanticHelper.interactive(
                testId: 'bookshelf_status_option_${status.name}',
                label: '「${book.title}」の読書状態を${status.label}に変更',
                child: Row(
                  children: [
                    _statusIcon(status),
                    const SizedBox(width: 12),
                    Text(status.label),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (result == null || result == book.readingStatus) return;

    final updated = switch (result) {
      ReadingStatus.unread => ReadingStatusService.markUnread(book),
      ReadingStatus.reading => ReadingStatusService.markStarted(book),
      ReadingStatus.finished => ReadingStatusService.markFinished(book),
    };
    await _updateReadingStatus(book, updated);
  }

  Widget _statusIcon(ReadingStatus status) {
    return Icon(switch (status) {
      ReadingStatus.unread => Icons.bookmark_border,
      ReadingStatus.reading => Icons.menu_book,
      ReadingStatus.finished => Icons.check_circle,
    });
  }

  /// 読書状態を表す小さなチップ
  Widget _readingStatusChip(Book book) {
    final color = switch (book.readingStatus) {
      ReadingStatus.unread => Colors.grey,
      ReadingStatus.reading => Colors.blue.shade700,
      ReadingStatus.finished => Colors.green.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusIcon(book.readingStatus),
          const SizedBox(width: 4),
          Text(
            book.readingStatus.label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 本棚 AppBar の1導線（宣言順 [index] と直置き優先度 [priority] を持つ）。
class _ShelfAction {
  final int index;
  final int priority;
  final Key key;
  final IconData icon;
  final String tooltip;
  final String? semanticTestId;
  final String? semanticLabel;
  final VoidCallback onPressed;

  const _ShelfAction({
    required this.index,
    required this.priority,
    required this.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.semanticTestId,
    this.semanticLabel,
  });
}
