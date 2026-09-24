import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/domain/book_note_service.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// お気に入りの引用を横断的に一覧表示する画面。
///
/// 全書籍のメモからお気に入りのみを抽出して表示する。
class FavoriteNotesScreen extends StatefulWidget {
  final BookNoteRepository repository;

  /// 書籍タイトル表示用の蔵書一覧
  final List<Book> books;

  const FavoriteNotesScreen({
    super.key,
    required this.repository,
    this.books = const [],
  });

  @override
  State<FavoriteNotesScreen> createState() => _FavoriteNotesScreenState();
}

class _FavoriteNotesScreenState extends State<FavoriteNotesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<BookNote> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final notes = await widget.repository.getAllNotes();
      if (mounted) {
        setState(() {
          _favorites = BookNoteService.favoritesOf(notes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// 書籍IDに対応するタイトル（見つからなければ「不明な書籍」）
  String _bookTitle(String bookId) {
    for (final book in widget.books) {
      if (book.id == bookId) return book.title;
    }
    return '不明な書籍';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_favorite_notes'),
      appBar: AppBar(
        title: const Text('お気に入りの引用'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        key: Key('favorite_loading_state'),
        child: CircularProgressIndicator(),
      );
    }
    if (_errorMessage != null) {
      return Center(
        key: const Key('favorite_error_state'),
        child: Text('エラー: $_errorMessage'),
      );
    }
    if (_favorites.isEmpty) {
      return const Center(
        key: Key('favorite_empty_state'),
        child: Text('お気に入りの引用はまだありません'),
      );
    }

    final grouped = BookNoteService.favoritesByBook(_favorites);
    final items = <Widget>[];
    for (final entry in grouped.entries) {
      final title = _bookTitle(entry.key);
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ));
      items.addAll(entry.value.map(_buildRow));
    }

    return SemanticHelper.container(
      testId: 'favorite_note_list',
      label: 'お気に入りの引用一覧',
      explicitChildNodes: true,
      child: ListView.builder(
        key: const Key('favorite_note_list'),
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    );
  }

  Widget _buildRow(BookNote note) {
    final title = _bookTitle(note.bookId);
    return SemanticHelper.container(
      testId: SemanticHelper.createTestId('item_favorite', note.id),
      label: '引用をお気に入りに追加済み: ${note.content}',
      child: ListTile(
        key: ValueKey('favorite_note_${note.id}'),
        title: Text(
          note.content,
          key: const Key('favorite_note_row'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title ・ ${note.pageLabel}'),
            if (note.tags.isNotEmpty)
              Text(note.tags.join('、'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
