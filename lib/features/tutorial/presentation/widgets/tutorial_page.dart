import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:book_review_app/features/tutorial/presentation/tutorial_content.dart';

/// チュートリアル1ページを縦に中央寄せで表示するウィジェット。
class TutorialPageView extends StatelessWidget {
  /// 表示するページデータ。
  final TutorialPageData data;

  /// チュートリアル1ページを表示する。
  const TutorialPageView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SemanticHelper.container(
      testId: data.keyName,
      label: '${data.title}の説明',
      child: Padding(
        key: data.pageKey,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(data.icon, size: 96, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              data.title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              data.body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
