import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_review_app/core/infrastructure/app_lock_gate.dart';
import 'package:book_review_app/core/theme/app_theme.dart';
import 'package:book_review_app/core/theme/theme_mode_repository.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/core/theme/text_scale_repository.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';
import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_bootstrap.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_service.dart';
import 'package:book_review_app/features/reminder/presentation/notification_tap_router.dart';
import 'package:book_review_app/features/tutorial/data/tutorial_repository.dart';
import 'package:book_review_app/features/tutorial/presentation/tutorial_screen.dart';
import 'package:book_review_app/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 通知タップ → 該当画面遷移の配線。
  // Navigator 構築前のタップは NotificationTapRouter 側で保留され、
  // 最初のフレーム後に流し込まれる。
  final loanRepository = HiveBookLoanRepository();
  await loanRepository.init();
  final tapRouter = NotificationTapRouter.forApp(
    navigatorKey: GlobalKey<NavigatorState>(),
    loanRepository: loanRepository,
  );
  final notificationService = BookNotificationService();
  unawaited(notificationService.initialize());

  // 起動時1日1回の自動バックアップ（世代3）。起動は待たせない。
  scheduleAutoBackup(buildJson: _buildAutoBackupJson);

  runApp(MyApp(notificationTapRouter: tapRouter));
}

/// 自動バックアップ用の JSON を組み立てる。
///
/// 手動バックアップ画面と同じ [HiveBackupRepository] を束ね、
/// [BackupService.exportJson] で整形する（画面側の実装は不変）。
Future<String> _buildAutoBackupJson() async {
  final bookRepository = HiveBookRepository();
  final reviewRepository = HiveReviewRepository();
  final noteRepository = HiveBookNoteRepository();
  await bookRepository.init();
  await reviewRepository.init();
  await noteRepository.init();
  final backupRepository = HiveBackupRepository(
    bookRepository: bookRepository,
    reviewRepository: reviewRepository,
    noteRepository: noteRepository,
  );
  final bundle = await backupRepository.collect();
  return const BackupService().exportJson(bundle);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.notificationTapRouter});

  /// 通知タップの遷移 router（null なら通知タップ配線なし）。
  final NotificationTapRouter? notificationTapRouter;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double _textScale = TextScaleSetting.normalScale;
  final TextScaleRepository _textScaleRepo = const TextScaleRepository();
  ThemeModeSetting _themeMode = ThemeModeSetting.system;
  final ThemeModeRepository _themeModeRepo = const ThemeModeRepository();
  ReduceMotionSetting _reduceMotion = ReduceMotionSetting.system;
  final ReduceMotionRepository _reduceMotionRepo =
      const ReduceMotionRepository();

  @override
  void initState() {
    super.initState();
    _loadTextScale();
    _loadThemeMode();
    _loadReduceMotion();
    _wireNotificationTaps();
  }

  /// 通知タップの遷移ハンドラを Navigator 構築後に接続する。
  ///
  /// 接続前に届いたタップ（起動経由を含む）は保留されており、
  /// 接続時に同じ入口から流し込まれる。
  void _wireNotificationTaps() {
    final router = widget.notificationTapRouter;
    if (router == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      BookNotificationService.attachGlobalRouteHandler(router.handle);
    });
  }

  /// 保存された「動きを減らす」設定を読み込む（未保存はシステム従属）。
  Future<void> _loadReduceMotion() async {
    final saved = await _reduceMotionRepo.load();
    if (mounted && saved != null) {
      setState(() => _reduceMotion = saved);
    }
  }

  /// 「動きを減らす」設定を変更する（永続化は設定画面が行う）。
  void _changeReduceMotion(ReduceMotionSetting setting) {
    setState(() => _reduceMotion = setting);
  }

  /// 保存されたテーマ設定を読み込む（未保存はシステム従属）。
  Future<void> _loadThemeMode() async {
    final saved = await _themeModeRepo.loadThemeMode();
    if (mounted && saved != null) {
      setState(() => _themeMode = saved);
    }
  }

  /// テーマを変更し、永続化する。
  Future<void> _changeThemeMode(ThemeModeSetting mode) async {
    await _themeModeRepo.saveThemeMode(mode);
    if (mounted) {
      setState(() => _themeMode = mode);
    }
  }

  /// 保存された文字サイズ倍率を読み込む（未保存は1.0）。
  Future<void> _loadTextScale() async {
    final saved = await _textScaleRepo.loadScale();
    if (mounted) {
      setState(() => _textScale = TextScaleSetting.normalized(saved));
    }
  }

  /// 文字サイズを変更し、永続化する。
  Future<void> _changeTextScale(double scale) async {
    await _textScaleRepo.saveScale(scale);
    if (mounted) {
      setState(() => _textScale = scale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.notificationTapRouter?.navigatorKey,
      title: 'book-review-app',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode.toThemeMode(),
      builder: (context, child) => MediaQuery(
        data: applyReduceMotion(
          MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_textScale),
          ),
          _reduceMotion,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppLockGate(
        unlockedBuilder: (context) => ErrorBoundary(
          child: _TutorialGate(
            repository: const HiveTutorialRepository(),
            child: MainScreen(
              textScale: _textScale,
              onScaleChanged: _changeTextScale,
              themeMode: _themeMode,
              onThemeModeChanged: _changeThemeMode,
              reduceMotion: _reduceMotion,
              onReduceMotionChanged: _changeReduceMotion,
            ),
          ),
        ),
      ),
    );
  }
}

/// チュートリアル完了状態を確認し、未完了なら TutorialScreen を表示するゲート。
class _TutorialGate extends StatefulWidget {
  /// 完了状態リポジトリ。
  final TutorialRepository repository;

  /// チュートリアル完了後に表示する画面。
  final Widget child;

  /// ゲートを生成する。
  const _TutorialGate({required this.repository, required this.child});

  @override
  State<_TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends State<_TutorialGate> {
  bool? _showTutorial;

  @override
  void initState() {
    super.initState();
    _check();
  }

  /// 完了状態を確認する（Hive 未初期化等の例外時はスキップ）。
  Future<void> _check() async {
    try {
      final done = await widget.repository.isCompleted();
      if (mounted) {
        setState(() => _showTutorial = !done);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _showTutorial = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = _showTutorial;
    if (show == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (show) {
      return TutorialScreen(
        repository: widget.repository,
        onFinished: () => setState(() => _showTutorial = false),
      );
    }
    return widget.child;
  }
}
