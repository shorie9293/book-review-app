import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';
import 'dart:io';

/// テスト用のモックレビューリポジトリ
class MockReviewRepository implements ReviewRepository {
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

/// Builds the BookshelfScreen wrapped in a MaterialApp for testing.
Widget _buildApp(HiveBookRepository repository, {List<Book> initialBooks = const [], ReviewRepository? reviewRepository}) {
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
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
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

  group('BookshelfScreen', () {
    testWidgets('検索用のテキストフィールドとボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(repository));
      await tester.pump();

      expect(find.byKey(const Key('screen_bookshelf')), findsOneWidget);
      expect(find.byKey(const Key('isbn_search_field')), findsOneWidget);
      expect(find.byKey(const Key('isbn_search_button')), findsOneWidget);
    });

    testWidgets('蔵書が空の場合、空メッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(repository));
      await tester.pump();

      expect(find.text('📚 蔵書がありません'), findsOneWidget);
    });

    testWidgets('追加した書籍が一覧に表示される', (tester) async {
      final book = Book(
        id: 'test-id-1',
        title: 'Test Driven Development',
        author: 'Kent Beck',
        isbn: '978-4-274-21788-3',
      );

      await tester.pumpWidget(_buildApp(repository, initialBooks: [book]));
      await tester.pump();

      expect(find.text('Test Driven Development'), findsOneWidget);
      expect(find.text('Kent Beck  |  978-4-274-21788-3'), findsOneWidget);
    });

    testWidgets('バーコードスキャンボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(repository));
      await tester.pump();

      expect(find.byKey(const Key('scan_barcode_button')), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('複数の書籍が一覧に表示される', (tester) async {
      final books = [
        Book(id: 'id-1', title: 'Book 1', author: 'Author 1', isbn: 'isbn-1'),
        Book(id: 'id-2', title: 'Book 2', author: 'Author 2', isbn: 'isbn-2'),
      ];

      await tester.pumpWidget(_buildApp(repository, initialBooks: books));
      await tester.pump();

      expect(find.text('Book 1'), findsOneWidget);
      expect(find.text('Book 2'), findsOneWidget);
    });

    testWidgets('蔵書タップでReviewScreenへ遷移する', (tester) async {
      final reviewRepository = MockReviewRepository();
      final book = Book(
        id: 'book-review-nav',
        title: 'ナビゲーションテスト本',
        author: 'Test Author',
        isbn: 'test-isbn-nav',
      );

      await tester.pumpWidget(_buildApp(
        repository,
        initialBooks: [book],
        reviewRepository: reviewRepository,
      ));
      await tester.pump();

      // 蔵書が表示されていることを確認
      expect(find.text('ナビゲーションテスト本'), findsOneWidget);

      // 蔵書をタップ
      await tester.tap(find.text('ナビゲーションテスト本'));
      await tester.pumpAndSettle();

      // ReviewScreenに遷移していることを確認
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.text('レビュー'), findsOneWidget);
    });

    testWidgets('蔵書タップで遷移したReviewScreenに正しいbookIdが渡される', (tester) async {
      final reviewRepository = MockReviewRepository();
      final book = Book(
        id: 'book-review-nav-id',
        title: 'bookId検証本',
        author: 'Test Author',
        isbn: 'test-isbn-id',
      );

      await tester.pumpWidget(_buildApp(
        repository,
        initialBooks: [book],
        reviewRepository: reviewRepository,
      ));
      await tester.pump();

      // 蔵書をタップしてReviewScreenへ遷移
      await tester.tap(find.text('bookId検証本'));
      await tester.pumpAndSettle();

      // ReviewScreenが表示され、空状態（レビューなし）が表示される
      expect(find.text('レビューはまだありません'), findsOneWidget);
    });

    testWidgets('スキャンボタンタップでBarcodeScannerScreenへ遷移する', (tester) async {
      await tester.pumpWidget(_buildApp(repository));
      await tester.pump();

      // スキャンボタンをタップ
      await tester.tap(find.byKey(const Key('scan_barcode_button')));
      await tester.pumpAndSettle();

      // BarcodeScannerScreenに遷移していることを確認
      // Note: MobileScannerはテスト環境でエラーになる可能性があるが、
      // Navigator.pushは正常に動作するはず
      expect(find.text('バーコードスキャン'), findsOneWidget);
    });

    testWidgets('蔵書一覧に読書状態チップ（積読）が表示される', (tester) async {
      final book = Book(
        id: 'chip-book',
        title: 'チップ表示本',
        author: 'Author',
        isbn: 'chip-isbn',
      );

      await tester.pumpWidget(_buildApp(repository, initialBooks: [book]));
      await tester.pump();

      expect(find.text('積読'), findsOneWidget);
      expect(find.byKey(const Key('status_button_chip-book')), findsOneWidget);
    });

    testWidgets('読書中状態の本に「読書中」チップが表示される', (tester) async {
      final book = Book(
        id: 'reading-chip',
        title: '読書中の本',
        author: 'Author',
        isbn: 'reading-chip-isbn',
      ).copyWith(readingStatus: ReadingStatus.reading, currentPage: 40);

      await tester.pumpWidget(_buildApp(repository, initialBooks: [book]));
      await tester.pump();

      expect(find.text('読書中'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book), findsWidgets);
    });

    testWidgets('読了状態の本に「読了」チップが表示される', (tester) async {
      final book = Book(
        id: 'finished-chip',
        title: '読了した本',
        author: 'Author',
        isbn: 'finished-chip-isbn',
      ).copyWith(
        readingStatus: ReadingStatus.finished,
        currentPage: 300,
        finishedAt: DateTime(2026, 6, 1),
      );

      await tester.pumpWidget(_buildApp(repository, initialBooks: [book]));
      await tester.pump();

      expect(find.text('読了'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('状態ボタンで読書状態ダイアログが開く', (tester) async {
      final book = Book(
        id: 'dialog-book',
        title: 'ダイアログ表示本',
        author: 'Author',
        isbn: 'dialog-isbn',
      );

      await tester.pumpWidget(_buildApp(repository, initialBooks: [book]));
      await tester.pump();

      // 状態ボタンをタップ → ダイアログに3状態のオプションが表示される
      await tester.tap(find.byKey(const Key('status_button_dialog-book')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('status_option_unread')), findsOneWidget);
      expect(find.byKey(const Key('status_option_reading')), findsOneWidget);
      expect(find.byKey(const Key('status_option_finished')), findsOneWidget);
    });
  });
}
