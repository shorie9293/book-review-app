import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';

/// バーコードスキャン画面
///
/// カメラでISBNバーコードをスキャンし、OpenBD APIで書籍情報を検索する。
/// スキャン結果が見つかった場合は確認ダイアログを表示し、
/// ユーザーが確認すると結果のBookを返す。
class BarcodeScannerScreen extends StatefulWidget {
  final BookSearchService searchService;

  const BarcodeScannerScreen({
    super.key,
    required this.searchService,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _cameraController =
      MobileScannerController();
  bool _isScanning = false;
  String? _lastScannedIsbn;
  DateTime? _lastScanTime;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanning) return;

    for (final barcode in capture.barcodes) {
      final isbn = barcode.rawValue;
      if (isbn == null || isbn.isEmpty) continue;

      // デバウンス: 同じISBNを2.5秒以内に再検出しない
      final now = DateTime.now();
      if (isbn == _lastScannedIsbn &&
          _lastScanTime != null &&
          now.difference(_lastScanTime!).inMilliseconds < 2500) {
        continue;
      }

      _lastScannedIsbn = isbn;
      _lastScanTime = now;

      _searchBook(isbn);
      return; // 最初の有効なバーコードのみ処理
    }
  }

  Future<void> _searchBook(String isbn) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final book = await widget.searchService.searchByIsbn(isbn);
      if (!mounted) return;

      if (book != null) {
        await _showConfirmationDialog(book);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('書籍が見つかりませんでした')),
        );
        _resumeScanning();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
      _resumeScanning();
    }
  }

  Future<void> _showConfirmationDialog(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('書籍を追加'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book.coverImageUrl != null &&
                  book.coverImageUrl!.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      book.coverImageUrl!,
                      width: 80,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 120,
                        color: Colors.grey[200],
                        child: const Icon(Icons.book, size: 48),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                book.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.author,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'ISBN: ${book.isbn}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      Navigator.pop(context, book);
    } else {
      _resumeScanning();
    }
  }

  void _resumeScanning() {
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バーコードスキャン'),
      ),
      body: Stack(
        children: [
          // カメラビュー
          LayoutBuilder(
            builder: (context, constraints) {
              final scanWidth = constraints.maxWidth * 0.7;
              final scanHeight = constraints.maxHeight * 0.35;
              final left = (constraints.maxWidth - scanWidth) / 2;
              final top = (constraints.maxHeight - scanHeight) / 2;

              return MobileScanner(
                controller: _cameraController,
                scanWindow: Rect.fromLTWH(left, top, scanWidth, scanHeight),
                onDetect: _onDetect,
              );
            },
          ),
          // ガイドテキスト
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'バーコードを枠内に合わせてください',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          // スキャン中表示
          if (_isScanning)
            Positioned.fill(
              child: Container(
                key: const Key('scan_loading_indicator'),
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
