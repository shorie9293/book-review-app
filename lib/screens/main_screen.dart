import 'package:flutter/material.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/queue/data/hive_reading_queue_repository.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_resync.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_resync_factory.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_export_coordinator.dart';
import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

class MainScreen extends StatefulWidget {
  /// 現在の文字サイズ倍率（設定画面へ渡す）
  final double textScale;

  /// 文字サイズ変更時のコールバック（永続化と全体再描画は上位で行う）
  final ValueChanged<double>? onScaleChanged;

  /// 現在のテーマ設定（設定画面へ渡す）
  final ThemeModeSetting themeMode;

  /// テーマ変更時のコールバック
  final ValueChanged<ThemeModeSetting>? onThemeModeChanged;

  /// 現在の「動きを減らす」設定
  final ReduceMotionSetting reduceMotion;

  /// 「動きを減らす」設定の変更コールバック
  final ValueChanged<ReduceMotionSetting>? onReduceMotionChanged;

  /// 返却期限リマインダーの再計算窓口
  /// （未指定なら本番の Hive 実装を内部生成する）
  final LoanDueReminderResync? reminderResync;

  const MainScreen({
    super.key,
    this.textScale = 1.0,
    this.onScaleChanged,
    this.themeMode = ThemeModeSetting.system,
    this.onThemeModeChanged,
    this.reduceMotion = ReduceMotionSetting.system,
    this.onReduceMotionChanged,
    this.reminderResync,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final HiveBookRepository _repository = HiveBookRepository();
  final HiveReviewRepository _reviewRepository = HiveReviewRepository();
  final HiveBookNoteRepository _noteRepository = HiveBookNoteRepository();
  final HiveReadingQueueRepository _queueRepository =
      HiveReadingQueueRepository();
  final HiveBookLoanRepository _loanRepository = HiveBookLoanRepository();

  /// クロスアプリ連携の userId 保管庫（初回アクセス時に uuid を採番）
  final HiveCrossAppLinkRepository _crossAppLinkRepository =
      const HiveCrossAppLinkRepository();

  /// 書き出し済み読了イベントの記録（冪等キー）
  final HiveRewardExportLogRepository _crossAppRewardLogRepository =
      const HiveRewardExportLogRepository();

  /// 読了イベント書き出しの調整役
  late final BookRewardExportCoordinator _rewardExportCoordinator =
      BookRewardExportCoordinator(
    linkRepository: _crossAppLinkRepository,
    logRepository: _crossAppRewardLogRepository,
  );

  bool _initialized = false;

  /// 起動時の再計算窓口（初回参照時に一度だけ解決する）
  LoanDueReminderResync? _reminderResyncCache;

  LoanDueReminderResync get _reminderResync => _reminderResyncCache ??=
      widget.reminderResync ??
          createHiveLoanDueReminderResync(
            loanRepository: _loanRepository,
            bookTitleLoader: _loadBookTitles,
          );

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    await _repository.init();
    await _reviewRepository.init();
    await _noteRepository.init();
    await _queueRepository.init();
    await _loanRepository.init();
    await _resyncLoanReminders();
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  /// 起動時の再計算（生成・実行の失敗は握りつぶし、起動を止めない）。
  Future<void> _resyncLoanReminders() async {
    try {
      await _reminderResync.trigger();
    } catch (_) {
      // 通知は副次的な機能なので起動は継続する
    }
  }

  /// bookId → 書名（通知本文に使う）。
  Future<Map<String, String>> _loadBookTitles() async {
    final books = await _repository.getBooks();
    return {for (final b in books) b.id: b.title};
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return SemanticHelper.container(
        testId: 'main_sec_loading',
        label: '読み込み中',
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return BookshelfScreen(
      repository: _repository,
      reviewRepository: _reviewRepository,
      noteRepository: _noteRepository,
      queueRepository: _queueRepository,
      loanRepository: _loanRepository,
      crossAppLinkRepository: _crossAppLinkRepository,
      crossAppRewardLogRepository: _crossAppRewardLogRepository,
      rewardExportCoordinator: _rewardExportCoordinator,
      reminderResync: _reminderResync,
      textScale: widget.textScale,
      onScaleChanged: widget.onScaleChanged,
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
      reduceMotion: widget.reduceMotion,
      onReduceMotionChanged: widget.onReduceMotionChanged,
    );
  }
}
