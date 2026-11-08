import 'package:flutter/material.dart';

import 'package:book_review_app/core/testing/app_keys.dart';

/// 検索語の履歴をチップとして並べる。
///
/// 空のときは何も描画しない（高さ 0）。タップされた検索語を [onSelected] で通知する。
class SearchHistoryChips extends StatelessWidget {
  /// 新しい順の検索語一覧。
  final List<String> entries;

  /// チップタップ時に検索語を通知する。
  final ValueChanged<String> onSelected;

  const SearchHistoryChips({
    super.key,
    required this.entries,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        key: AppKeys.librarySearchHistoryChips,
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final entry in entries)
            ActionChip(
              key: AppKeys.librarySearchHistoryChip(entry),
              label: Text(entry),
              onPressed: () => onSelected(entry),
            ),
        ],
      ),
    );
  }
}
