import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:book_review_app/core/testing/app_keys.dart' as keys;
import 'package:book_review_app/features/tutorial/data/tutorial_repository.dart'
    as repo;
import 'package:book_review_app/features/tutorial/domain/tutorial_progress.dart';
import 'package:book_review_app/features/tutorial/presentation/tutorial_content.dart';
import 'package:book_review_app/features/tutorial/presentation/widgets/tutorial_page.dart';

/// 初回オンボーディングのチュートリアル画面。
class TutorialScreen extends StatefulWidget {
  /// 完了状態のリポジトリ（注入）。
  final repo.TutorialRepository repository;

  /// 完了・スキップ時に発火するコールバック。
  final VoidCallback? onFinished;

  /// ページ定義（注入可。null なら TutorialContent.pages）。
  final List<TutorialPageData>? pages;

  /// チュートリアル画面を生成する。
  const TutorialScreen({
    super.key,
    required this.repository,
    this.onFinished,
    this.pages,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final PageController _controller;
  int _currentPage = 0;

  /// 注入されたページ定義、または既定コンテンツ。
  /// State 再利用時の陳腐化を避けるため必ず getter で解決する。
  List<TutorialPageData> get _pages => widget.pages ?? TutorialContent.pages;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await widget.repository.markCompleted();
    widget.onFinished?.call();
  }

  void _next() {
    if (_currentPage >= _pages.length - 1) {
      _complete();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = TutorialProgress(
      currentPage: _currentPage.clamp(0, _pages.length - 1),
      totalPages: _pages.length,
    );
    final isLast = progress.isLast;

    return SemanticHelper.container(
      testId: 'screen_tutorial',
      label: 'チュートリアル',
      child: Scaffold(
        key: keys.AppKeys.tutorialScreen,
        appBar: AppBar(
          actions: [
            TextButton(
              key: keys.AppKeys.tutorialSkip,
              onPressed: _complete,
              child: const Text('スキップ'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: _pages.map((p) => TutorialPageView(data: p)).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progress.label,
                    key: keys.AppKeys.tutorialIndicator,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  FilledButton(
                    key: keys.AppKeys.tutorialNext,
                    onPressed: _next,
                    child: Text(isLast ? 'はじめる' : '次へ'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
