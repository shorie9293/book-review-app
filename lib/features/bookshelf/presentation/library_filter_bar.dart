import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';

/// 本棚の検索・絞り込み・並び替え操作を提供するフィルタバー。
class LibraryFilterBar extends StatelessWidget {
  final LibraryQuery query;

  /// 本棚全体の件数
  final int totalCount;

  /// 絞り込み後の表示件数
  final int filteredCount;

  final ValueChanged<LibraryQuery> onChanged;

  /// 絞り込みに提示するジャンル一覧（件数降順・正規化済み）。
  final List<String> genres;

  /// ジャンルごとの蔵書件数（チップの表示用）。
  final Map<String, int> genreCounts;

  const LibraryFilterBar({
    super.key,
    required this.query,
    required this.totalCount,
    required this.filteredCount,
    required this.onChanged,
    this.genres = const [],
    this.genreCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters = query.activeFilterCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('library_search_field'),
                  controller: TextEditingController(text: query.text),
                  decoration: const InputDecoration(
                    labelText: 'タイトル/著者検索',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      onChanged(query.copyWith(text: value)),
                ),
              ),
              PopupMenuButton<LibrarySortOrder>(
                key: const Key('library_sort_button'),
                tooltip: '並び替え',
                icon: const Icon(Icons.sort),
                initialValue: query.sortOrder,
                onSelected: (order) =>
                    onChanged(query.copyWith(sortOrder: order)),
                itemBuilder: (context) => [
                  for (final order in LibrarySortOrder.values)
                    PopupMenuItem(
                      value: order,
                      child: Text(order.label),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final status in ReadingStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    key: Key('library_status_chip_${status.name}'),
                    label: Text(status.label),
                    selected: query.statuses.contains(status),
                    onSelected: (selected) {
                      final next = Set<ReadingStatus>.from(query.statuses);
                      selected ? next.add(status) : next.remove(status);
                      onChanged(query.copyWith(statuses: next));
                    },
                  ),
                ),
              const Spacer(),
              Text(
                '$filteredCount / $totalCount 冊',
                key: const Key('library_count_text'),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('library_reset_button'),
                  onPressed: () => onChanged(const LibraryQuery()),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('リセット'),
                ),
              ],
            ],
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 40,
              child: ListView(
                key: const Key('library_genre_chip_list'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final genre in genres)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: AppKeys.genreFilterChip(genre),
                        label: Text(
                          genreCounts[genre] != null
                              ? '$genre (${genreCounts[genre]})'
                              : genre,
                        ),
                        selected: query.genres.contains(genre),
                        onSelected: (selected) {
                          final next = Set<String>.from(query.genres);
                          selected ? next.add(genre) : next.remove(genre);
                          onChanged(query.copyWith(genres: next));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
