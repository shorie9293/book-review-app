import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/bookshelf/domain/reading_status_service.dart';
import 'package:book_review_app/features/bookshelf/presentation/barcode_scanner_screen.dart';
import 'package:book_review_app/features/challenge/presentation/challenge_screen.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';

class BookshelfScreen extends StatefulWidget {
  final BookRepository repository;
  final BookSearchService? searchService;
  final List<Book> initialBooks;
  final ReviewRepository? reviewRepository;

  const BookshelfScreen({
    super.key,
    required this.repository,
    this.searchService,
    this.initialBooks = const [],
    this.reviewRepository,
  });

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  final TextEditingController _isbnController = TextEditingController();
  final BookSearchService _searchService = BookSearchService();
  late List<Book> _books;
  Book? _foundBook;
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _books = List<Book>.from(widget.initialBooks);
  }

  @override
  void dispose() {
    _isbnController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    final books = await widget.repository.getBooks();
    if (mounted) {
      setState(() {
        _books = books;
      });
    }
  }

  Future<void> _searchByIsbn() async {
    final isbn = _isbnController.text.trim();
    if (isbn.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundBook = null;
      _errorMessage = null;
    });

    try {
      final service = widget.searchService ?? _searchService;
      final book = await service.searchByIsbn(isbn);
      if (mounted) {
        setState(() {
          _foundBook = book;
          _isSearching = false;
          if (book == null) {
            _errorMessage = '書籍が見つかりませんでした';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = '検索中にエラーが発生しました: $e';
        });
      }
    }
  }

  Future<void> _addBookToShelf(Book book) async {
    final uuid = _generateUuid();
    final newBook = Book(
      id: uuid,
      title: book.title,
      author: book.author,
      isbn: book.isbn,
      coverImageUrl: book.coverImageUrl,
      publisher: book.publisher,
      publishedDate: book.publishedDate,
      pageCount: book.pageCount,
      description: book.description,
    );

    await widget.repository.addBook(newBook);
    await _loadBooks();

    if (mounted) {
      setState(() {
        _foundBook = null;
        _isbnController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${book.title}」を本棚に追加しました')),
        );
      });
    }
  }

  String _generateUuid() {
    // Simple UUID v4-like generation
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = (timestamp * 37 + 17) % 0xFFFFFFFF;
    return '$timestamp-$random-${_books.length + 1}';
  }

  Future<void> _openBarcodeScanner() async {
    final service = widget.searchService ?? _searchService;
    final scannedBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(searchService: service),
      ),
    );
    if (scannedBook != null && mounted) {
      await _addBookToShelf(scannedBook);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_bookshelf'),
      appBar: AppBar(
        title: const Text('本棚'),
        actions: [
          IconButton(
            key: const Key('challenge_button'),
            icon: const Icon(Icons.emoji_events),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChallengeScreen(),
                ),
              );
            },
            tooltip: '年間読書チャレンジ',
          ),
          IconButton(
            key: const Key('scan_barcode_button'),
            icon: const Icon(Icons.camera_alt),
            onPressed: _openBarcodeScanner,
            tooltip: 'バーコードスキャン',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          Divider(),
          Expanded(child: _buildBookList()),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('isbn_search_field'),
                  controller: _isbnController,
                  decoration: const InputDecoration(
                    labelText: 'ISBNで検索',
                    hintText: '978-4-7741-8907-9',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('isbn_search_button'),
                onPressed: _isSearching ? null : _searchByIsbn,
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('検索'),
              ),
            ],
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          if (_foundBook != null)
            _buildFoundBookCard(_foundBook!),
        ],
      ),
    );
  }

  Widget _buildFoundBookCard(Book book) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  book.coverImageUrl!,
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[200],
                    child: const Icon(Icons.book, size: 40),
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 90,
                color: Colors.grey[200],
                child: const Icon(Icons.book, size: 40),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(book.author, style: TextStyle(color: Colors.grey[600])),
                  if (book.publisher != null) Text(book.publisher!, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addBookToShelf(book),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('本棚に追加'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList() {
    if (_books.isEmpty) {
      return const Center(child: Text('📚 蔵書がありません'));
    }

    return ListView.builder(
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return ListTile(
            leading: book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      book.coverImageUrl!,
                      width: 40,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.book),
                    ),
                  )
                : const Icon(Icons.book, size: 40),
            title: Text(book.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${book.author}  |  ${book.isbn}'),
                const SizedBox(height: 4),
                _readingStatusChip(book),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('status_button_${book.id}'),
                  icon: _statusIcon(book.readingStatus),
                  tooltip: '読書状態を変更',
                  onPressed: () => _showReadingStatusDialog(book),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await widget.repository.removeBook(book.id);
                    await _loadBooks();
                  },
                ),
              ],
            ),
            onTap: () => _navigateToReviews(book),
          );
        },
    );
  }

  void _navigateToReviews(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          bookId: book.id,
          reviewRepository: widget.reviewRepository!,
        ),
      ),
    );
  }

  /// 読書状態を更新し保存する
  Future<void> _updateReadingStatus(Book book, Book updated) async {
    await widget.repository.updateBook(updated);
    await _loadBooks();
  }

  /// 読書状態変更ダイアログを表示する
  Future<void> _showReadingStatusDialog(Book book) async {
    final result = await showDialog<ReadingStatus>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('「${book.title}」の読書状態'),
        children: [
          for (final status in ReadingStatus.values)
            SimpleDialogOption(
              key: Key('status_option_${status.name}'),
              onPressed: () => Navigator.of(context).pop(status),
              child: Row(
                children: [
                  _statusIcon(status),
                  const SizedBox(width: 12),
                  Text(status.label),
                ],
              ),
            ),
        ],
      ),
    );
    if (result == null || result == book.readingStatus) return;

    final updated = switch (result) {
      ReadingStatus.unread => ReadingStatusService.markUnread(book),
      ReadingStatus.reading => ReadingStatusService.markStarted(book),
      ReadingStatus.finished => ReadingStatusService.markFinished(book),
    };
    await _updateReadingStatus(book, updated);
  }

  Widget _statusIcon(ReadingStatus status) {
    return Icon(switch (status) {
      ReadingStatus.unread => Icons.bookmark_border,
      ReadingStatus.reading => Icons.menu_book,
      ReadingStatus.finished => Icons.check_circle,
    });
  }

  /// 読書状態を表す小さなチップ
  Widget _readingStatusChip(Book book) {
    final color = switch (book.readingStatus) {
      ReadingStatus.unread => Colors.grey,
      ReadingStatus.reading => Colors.blue.shade700,
      ReadingStatus.finished => Colors.green.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusIcon(book.readingStatus),
          const SizedBox(width: 4),
          Text(
            book.readingStatus.label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
