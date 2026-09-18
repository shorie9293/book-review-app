import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/reading_queue_repository.dart';
import 'package:book_review_app/features/queue/presentation/viewmodel/reading_queue_view_model.dart';

/// 「次に読む」キュー画面。
///
/// 積読の中から読む順序を管理し、次に読む1冊を明示する。
/// repository / books を注入できるため、実 Hive に触れずに検証できる。
class ReadingQueueScreen extends StatefulWidget {
  final ReadingQueueRepository repository;

  /// キュー解決に使う書籍一覧（未指定なら [booksLoader] を使う）
  final List<Book>? books;

  /// 書籍一覧の取得関数（[books] 未指定時に使用）
  final Future<List<Book>> Function()? booksLoader;

  const ReadingQueueScreen({
    super.key,
    required this.repository,
    this.books,
    this.booksLoader,
  });

  @override
  State<ReadingQueueScreen> createState() => _ReadingQueueScreenState();
}

class _ReadingQueueScreenState extends State<ReadingQueueScreen> {
  late final ReadingQueueViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ReadingQueueViewModel(
      booksLoader: widget.booksLoader,
      initialBooks: widget.books,
    );
    _viewModel.load(widget.repository, books: widget.books);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_reading_queue'),
      appBar: AppBar(
        title: const Text('次に読む'),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('reading_queue_add_fab'),
        onPressed: _openAddSheet,
        tooltip: '積読から追加',
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(
              key: Key('reading_queue_loading'),
              child: CircularProgressIndicator(),
            );
          }
          if (_viewModel.errorMessage != null) {
            return Center(
              key: const Key('reading_queue_error'),
              child: Text('読み込みに失敗しました: ${_viewModel.errorMessage}'),
            );
          }
          final queue = _viewModel.queue;
          if (queue.isEmpty) {
            return const Center(
              key: Key('reading_queue_empty_state'),
              child: Text('キューが空です。本を追加しましょう'),
            );
          }
          final next = _viewModel.nextToRead!;
          return ListView(
            children: [
              Card(
                key: const Key('reading_queue_next_card'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('次に読む一冊',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        next.title,
                        key: Key('reading_queue_next_title'),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(next.author),
                    ],
                  ),
                ),
              ),
              const Divider(),
              for (var i = 0; i < queue.length; i++)
                _buildRow(context, i + 1, queue[i], i == 0,
                    i == queue.length - 1),
            ],
          );
        },
      ),
    );
  }

  /// 積読から本を選んでキュー末尾に追加するシートを開く。
  Future<void> _openAddSheet() async {
    final candidates = _viewModel.candidates;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          key: const Key('reading_queue_candidate_sheet'),
          shrinkWrap: true,
          children: candidates.isEmpty
              ? const [
                  ListTile(
                    key: Key('reading_queue_no_candidate'),
                    leading: Icon(Icons.info_outline),
                    title: Text('追加できる積読がありません'),
                  ),
                ]
              : [
                  for (final book in candidates)
                    ListTile(
                      key: Key('reading_queue_candidate_${book.id}'),
                      leading: const Icon(Icons.menu_book),
                      title: Text(book.title),
                      subtitle: Text(book.author),
                      trailing: const Icon(Icons.add),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _viewModel.add(widget.repository, book.id);
                      },
                    ),
                ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    int position,
    Book book,
    bool isFirst,
    bool isLast,
  ) {
    return ListTile(
      key: Key('reading_queue_row_${book.id}'),
      leading: Text('$position.'),
      title: Text(book.title),
      subtitle: Text(book.author),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('reading_queue_move_up_button'),
            icon: const Icon(Icons.arrow_upward),
            onPressed: isFirst
                ? null
                : () => _viewModel.moveUp(widget.repository, book.id),
            tooltip: '前へ',
          ),
          IconButton(
            key: const Key('reading_queue_move_down_button'),
            icon: const Icon(Icons.arrow_downward),
            onPressed: isLast
                ? null
                : () => _viewModel.moveDown(widget.repository, book.id),
            tooltip: '後へ',
          ),
          IconButton(
            key: const Key('reading_queue_remove_button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _viewModel.remove(widget.repository, book.id),
            tooltip: 'キューから削除',
          ),
        ],
      ),
    );
  }
}
