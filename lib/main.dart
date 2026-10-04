import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_review_app/core/theme/app_theme.dart';
import 'package:book_review_app/core/theme/theme_mode_repository.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/core/theme/text_scale_repository.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:book_review_app/features/tutorial/data/tutorial_repository.dart';
import 'package:book_review_app/features/tutorial/presentation/tutorial_screen.dart';
import 'package:book_review_app/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double _textScale = TextScaleSetting.normalScale;
  final TextScaleRepository _textScaleRepo = const TextScaleRepository();
  ThemeModeSetting _themeMode = ThemeModeSetting.system;
  final ThemeModeRepository _themeModeRepo = const ThemeModeRepository();

  @override
  void initState() {
    super.initState();
    _loadTextScale();
    _loadThemeMode();
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
      title: 'book-review-app',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode.toThemeMode(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_textScale),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: ErrorBoundary(
        child: _TutorialGate(
          repository: const HiveTutorialRepository(),
          child: MainScreen(
            textScale: _textScale,
            onScaleChanged: _changeTextScale,
            themeMode: _themeMode,
            onThemeModeChanged: _changeThemeMode,
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
