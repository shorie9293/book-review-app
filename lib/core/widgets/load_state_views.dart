import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 読み込み失敗の表示。
///
/// 「0件」([LoadEmptyView]) とは別ウィジェットにし、文言も必ず分ける。
/// [onRetry] が null なら再試行ボタンを出さない（再試行不能な失敗）。
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        key: const ValueKey('load_error_view'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              SemanticHelper.interactive(
                testId: 'load_retry_button',
                label: '読み込みを再試行する',
                child: FilledButton.tonal(
                  key: const ValueKey('load_retry_button'),
                  onPressed: onRetry,
                  child: const Text('再試行'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 読み込み成功かつ0件の表示。
class LoadEmptyView extends StatelessWidget {
  const LoadEmptyView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        key: const ValueKey('load_empty_view'),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
