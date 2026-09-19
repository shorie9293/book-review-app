import 'package:flutter/material.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/queue/data/hive_reading_queue_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';

class MainScreen extends StatefulWidget {
  /// 現在の文字サイズ倍率（設定画面へ渡す）
  final double textScale;

  /// 文字サイズ変更時のコールバック（永続化と全体再描画は上位で行う）
  final ValueChanged<double>? onScaleChanged;

  const MainScreen({
    super.key,
    this.textScale = 1.0,
    this.onScaleChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final HiveBookRepository _repository = HiveBookRepository();
  final HiveReviewRepository _reviewRepository = HiveReviewRepository();
  final HiveBookNoteRepository _noteRepository = HiveBookNoteRepository();
  final HiveReadingQueueRepository _queueRepository =
      HiveReadingQueueRepository();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    await _repository.init();
    await _reviewRepository.init();
    await _noteRepository.init();
    await _queueRepository.init();
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return BookshelfScreen(
      repository: _repository,
      reviewRepository: _reviewRepository,
      noteRepository: _noteRepository,
      queueRepository: _queueRepository,
      textScale: widget.textScale,
      onScaleChanged: widget.onScaleChanged,
    );
  }
}
