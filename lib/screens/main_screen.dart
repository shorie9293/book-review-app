import 'package:flutter/material.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final HiveBookRepository _repository = HiveBookRepository();
  final HiveReviewRepository _reviewRepository = HiveReviewRepository();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    await _repository.init();
    await _reviewRepository.init();
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
    );
  }
}
