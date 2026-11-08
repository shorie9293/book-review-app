import 'dart:async';

import 'package:flutter/material.dart';
import 'package:book_review_app/core/search/search_history.dart';
import 'package:book_review_app/core/search/search_history_chips.dart';
import 'package:book_review_app/core/search/search_history_store.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';

/// 本棚の検索・絞り込み・並び替え操作を提供するフィルタバー。
class LibraryFilterBar extends StatefulWidget {
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

  /// 絞り込みに提示する所在一覧（件数降順・正規化済み）。
  final List<String> locations;

  /// 所在ごとの蔵書件数（チップの表示用）。
  final Map<String, int> locationCounts;

  /// 検索語履歴の永続化先。未指定なら SharedPreferences 実装を用いる。
  final SearchHistoryStore? searchHistoryStore;

  const LibraryFilterBar({
    super.key,
    required this.query,
    required this.totalCount,
    required this.filteredCount,
    required this.onChanged,
    this.genres = const [],
    this.genreCounts = const {},
    this.locations = const [],
    this.locationCounts = const {},
    this.searchHistoryStore,
  });

  @override
  State<LibraryFilterBar> createState() => _LibraryFilterBarState();
}

class _LibraryFilterBarState extends State<LibraryFilterBar> {
  late final SearchHistoryStore _store;
  late final TextEditingController _controller;
  SearchHistory _history = SearchHistory();

  @override
  void initState() {
    super.initState();
    _store = widget.searchHistoryStore ?? const SharedPreferencesSearchHistoryStore();
    _controller = TextEditingController(text: widget.query.text);
    unawaited(_restoreHistory());
  }

  Future<void> _restoreHistory() async {
    final loaded = await _loadSilently();
    if (!mounted || loaded.isEmpty) return;
    setState(() => _history = loaded);
  }

  Future<SearchHistory> _loadSilently() async {
    try {
      return await _store.load();
    } catch (_) {
      // 永続化基盤が無い環境（試練・初期化前）では履歴なしとして扱う。
      return SearchHistory();
    }
  }

  Future<void> _saveSilently(SearchHistory history) async {
    try {
      await _store.save(history);
    } catch (_) {
      // 保存失敗は検索操作を妨げない。
    }
  }

  @override
  void didUpdateWidget(covariant LibraryFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query.text != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query.text,
        selection: TextSelection.collapsed(offset: widget.query.text.length),
      );
    }
  }

  /// 現在の検索語を履歴へ積み、永続化する（空語は無視）。
  void _submitCurrent(String value) {
    if (SearchHistory.normalize(value).isEmpty) return;
    setState(() => _history = _history.add(value));
    unawaited(_saveSilently(_history));
  }

  /// 履歴チップのタップ: 入力欄と絞り込み状態を同時に更新する。
  void _applyHistory(String term) {
    _controller.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    widget.onChanged(widget.query.copyWith(text: term));
  }

  @override
  void dispose() {
    // 画面離脱時に、入力中の検索語が非空なら履歴へ残す。
    if (SearchHistory.normalize(_controller.text).isNotEmpty) {
      unawaited(_saveSilently(_history.add(_controller.text)));
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
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
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'タイトル/著者検索',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      widget.onChanged(query.copyWith(text: value)),
                  onSubmitted: _submitCurrent,
                ),
              ),
              PopupMenuButton<LibrarySortOrder>(
                key: const Key('library_sort_button'),
                tooltip: '並び替え',
                icon: const Icon(Icons.sort),
                initialValue: query.sortOrder,
                onSelected: (order) =>
                    widget.onChanged(query.copyWith(sortOrder: order)),
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
          SearchHistoryChips(
            entries: _history.entries,
            onSelected: _applyHistory,
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
                      widget.onChanged(query.copyWith(statuses: next));
                    },
                  ),
                ),
              const Spacer(),
              Text(
                '${widget.filteredCount} / ${widget.totalCount} 冊',
                key: const Key('library_count_text'),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('library_reset_button'),
                  onPressed: () => widget.onChanged(const LibraryQuery()),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('リセット'),
                ),
              ],
            ],
          ),
          if (widget.genres.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 40,
              child: ListView(
                key: const Key('library_genre_chip_list'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final genre in widget.genres)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: AppKeys.genreFilterChip(genre),
                        label: Text(
                          widget.genreCounts[genre] != null
                              ? '$genre (${widget.genreCounts[genre]})'
                              : genre,
                        ),
                        selected: query.genres.contains(genre),
                        onSelected: (selected) {
                          final next = Set<String>.from(query.genres);
                          selected ? next.add(genre) : next.remove(genre);
                          widget.onChanged(query.copyWith(genres: next));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (widget.locations.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 40,
              child: ListView(
                key: const Key('library_location_chip_list'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final location in widget.locations)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: AppKeys.locationFilterChip(location),
                        label: Text(
                          widget.locationCounts[location] != null
                              ? '$location (${widget.locationCounts[location]})'
                              : location,
                        ),
                        selected: query.locations.contains(location),
                        onSelected: (selected) {
                          final next = Set<String>.from(query.locations);
                          selected ? next.add(location) : next.remove(location);
                          widget.onChanged(query.copyWith(locations: next));
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
