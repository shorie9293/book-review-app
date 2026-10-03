import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/domain/stagnation.dart';
import 'package:flutter/material.dart';

/// 積読・放置本の停滞一覧画面。
///
/// 本棚の現時点の蔵書を受け取り、純粋な [StagnationService] で
/// 停滞判定して優先提示する（読み取り専用）。
class StagnantBooksScreen extends StatefulWidget {
  const StagnantBooksScreen({
    super.key,
    required this.books,
    this.now,
    this.initialMinDays = StagnationService.defaultMinDays,
  });

  /// 判定対象の蔵書（本棚の現状態）。
  final List<Book> books;

  /// 実時計の注入点（試練で固定する）。
  final DateTime? now;

  /// 初期の停滞判定閾値（日）。
  final int initialMinDays;

  @override
  State<StagnantBooksScreen> createState() => _StagnantBooksScreenState();
}

class _StagnantBooksScreenState extends State<StagnantBooksScreen> {
  late int _minDays = widget.initialMinDays;
  StagnationReason? _reasonFilter;
  String _query = '';

  List<StagnationEntry> get _entries {
    final now = widget.now ?? DateTime.now();
    final detected =
        StagnationService.detect(widget.books, now: now, minDays: _minDays);
    final byReason = StagnationService.filterByReason(detected, _reasonFilter);
    return StagnationService.sortByDays(
        StagnationService.searchByText(byReason, _query));
  }

  Map<StagnationReason, int> get _counts {
    final now = widget.now ?? DateTime.now();
    return StagnationService.countsByReason(
      StagnationService.detect(widget.books, now: now, minDays: _minDays),
    );
  }

  bool get _isDefaultQuery =>
      _query.isEmpty && _reasonFilter == null && _minDays == widget.initialMinDays;

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('停滞している本')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              key: AppKeys.stagnantSearchField,
              decoration: InputDecoration(
                hintText: '書名・著者で検索',
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: AppKeys.stagnantSearchClear,
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final days in StagnationService.minDaysChoices)
                ChoiceChip(
                  key: AppKeys.stagnantMinChip(days),
                  label: Text('$days日以上'),
                  selected: _minDays == days,
                  onSelected: (_) => setState(() => _minDays = days),
                ),
            ],
          ),
          _buildReasonChips(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entries.length}件',
                    key: AppKeys.stagnantCountLabel,
                  ),
                  const SizedBox(width: 8),
                  if (!_isDefaultQuery)
                    TextButton(
                      onPressed: () => setState(() {
                        _query = '';
                        _reasonFilter = null;
                        _minDays = widget.initialMinDays;
                      }),
                      child: const Text('リセット'),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildList(entries)),
        ],
      ),
    );
  }

  Widget _buildReasonChips() {
    final counts = _counts;
    return Wrap(
      spacing: 8,
      children: [
        for (final reason in StagnationReason.values)
          ChoiceChip(
            key: AppKeys.stagnantReasonChip(reason.name),
            label: Text('${reason.label} (${counts[reason] ?? 0})'),
            selected: _reasonFilter == reason,
            onSelected: (selected) => setState(() {
              _reasonFilter = selected ? reason : null;
            }),
          ),
      ],
    );
  }

  Widget _buildList(List<StagnationEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          key: AppKeys.stagnantEmpty,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.hourglass_disabled, size: 48),
            SizedBox(height: 8),
            Text('停滞している本はありません'),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final book = entry.book;
        final progress = entry.progressLabel();
        return ListTile(
          key: AppKeys.stagnantEntry(book.id),
          title: Text(book.title),
          subtitle: Text(
            '${book.author}'
            '${progress == null ? '' : '・$progress'}'
            '・${entry.reason.label}',
          ),
          trailing: Text(
            entry.daysLabel,
            key: AppKeys.stagnantDays(book.id),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      },
    );
  }
}