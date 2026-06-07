import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';
import 'dart:io';

/// テスト用のモックレビューリポジトリ
class _MockReviewRepo implements ReviewRepository {
  final Map<String, List<Review>> _store = {};

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async {
    return _store[bookId]?.toList() ?? [];
  }

  @override
  Future<void> addReview(Review review) async {
    _store.putIfAbsent(review.bookId, () => []);
    _store[review.bookId]!.add(review);
  }

  @override
  Future<void> updateReview(Review review) async {
    final list = _store[review.bookId];
    if (list != null) {
      final index = list.indexWhere((r) => r.id == review.id);
      if (index != -1) list[index] = review;
    }
  }

  @override
  Future<void> deleteReview(String id) async {
    for (final list in _store.values) {
      list.removeWhere((r) => r.id == id);
    }
  }
}

Widget _buildApp(HiveBookRepository repository, {
  List<Book> initialBooks = const [],
  ReviewRepository? reviewRepository,
}) {
  return MaterialApp(
    home: BookshelfScreen(
      repository: repository,
      initialBooks: initialBooks,
      reviewRepository: reviewRepository,
    ),
  );
}

void main() {
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_int_test_');
    Hive.init(tempDir.path);
    repository = HiveBookRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await repository.close();
    await Hive.deleteBoxFromDisk('books');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Integration: BookshelfScreen → ReviewScreen', () {
    testWidgets('navigates with correct bookId and shows empty reviews',
        (tester) async {
      final reviewRepository = _MockReviewRepo();
      final book = Book(
        id: 'integration-book-1',
        title: 'Integration Test Book',
        author: 'Test Author',
        isbn: 'int-isbn-001',
      );

      await tester.pumpWidget(_buildApp(
        repository,
        initialBooks: [book],
        reviewRepository: reviewRepository,
      ));
      await tester.pumpAndSettle();

      // Verify book is in shelf
      expect(find.text('Integration Test Book'), findsOneWidget);

      // Navigate to ReviewScreen
      await tester.tap(find.text('Integration Test Book'));
      await tester.pumpAndSettle();

      // Verify navigation
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.text('レビュー'), findsOneWidget);
      expect(find.text('レビューはまだありません'), findsOneWidget);
    });

    testWidgets('navigates, adds review, returns and verifies',
        (tester) async {
      final reviewRepository = _MockReviewRepo();
      final book = Book(
        id: 'integration-book-2',
        title: 'Round Trip Test',
        author: 'Test Author',
        isbn: 'int-isbn-002',
      );

      await tester.pumpWidget(_buildApp(
        repository,
        initialBooks: [book],
        reviewRepository: reviewRepository,
      ));
      await tester.pumpAndSettle();

      // Navigate to ReviewScreen
      await tester.tap(find.text('Round Trip Test'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewScreen), findsOneWidget);

      // Add a review
      await tester.tap(find.byKey(const Key('review_add_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_form_star_4')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('review_form_text_field')),
        'Integration review',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_form_save_button')));
      await tester.pumpAndSettle();

      // Verify review is shown
      expect(find.text('Integration review'), findsOneWidget);

      // Navigate back to BookshelfScreen
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify we're back at BookshelfScreen
      expect(find.byKey(const Key('screen_bookshelf')), findsOneWidget);
      expect(find.text('Round Trip Test'), findsOneWidget);
    });
  });

  group('Integration: BookshelfScreen → BarcodeScannerScreen', () {
    testWidgets('navigates to scanner and sees scanner UI', (tester) async {
      await tester.pumpWidget(_buildApp(repository));
      await tester.pumpAndSettle();

      // Tap scan button
      await tester.tap(find.byKey(const Key('scan_barcode_button')));
      await tester.pumpAndSettle();

      // Verify scanner screen is displayed
      expect(find.text('バーコードスキャン'), findsOneWidget);
    });

    testWidgets('scanner screen shows guide text and has AppBar back button',
        (tester) async {
      await tester.pumpWidget(_buildApp(repository));
      await tester.pumpAndSettle();

      // Navigate to scanner
      await tester.tap(find.byKey(const Key('scan_barcode_button')));
      await tester.pumpAndSettle();

      // Verify scanner UI
      expect(find.text('バーコードを枠内に合わせてください'), findsOneWidget);
      // AppBar should have a back button
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('can navigate back from scanner to bookshelf', (tester) async {
      await tester.pumpWidget(_buildApp(repository));
      await tester.pumpAndSettle();

      // Navigate to scanner
      await tester.tap(find.byKey(const Key('scan_barcode_button')));
      await tester.pumpAndSettle();

      expect(find.text('バーコードスキャン'), findsOneWidget);

      // Navigate back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify back at bookshelf
      expect(find.byKey(const Key('screen_bookshelf')), findsOneWidget);
    });
  });
}
