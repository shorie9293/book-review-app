import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/review/presentation/review_search_screen.dart';

/// 試練用のインメモリ蔵書リポジトリ
class _FakeBookRepository implements BookRepository {
  final List<Book> books;

  _FakeBookRepository(this.books);

  @override
  Future<List<Book>> getBooks() async => List<Book>.from(books);

  @override
  Future<Book?> getBookById(String id) async {
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<Book?> findByIsbn(String isbn) async {
    for (final book in books) {
      if (book.isbn == isbn) return book;
    }
    return null;
  }

  @override
  Future<void> addBook(Book book) async => books.add(book);

  @override
  Future<void> updateBook(Book book) async {}

  @override
  Future<void> removeBook(String id) async =>
      books.removeWhere((book) => book.id == id);
}

/// 試練用のインメモリレビューリポジトリ（任意で例外を投げる）
class _FakeReviewRepository implements ReviewRepository {
  final Map<String, List<Review>> _store;

  /// 残り失敗回数（0 なら成功）
  int failuresRemaining;

  _FakeReviewRepository(List<Review> reviews, {this.failuresRemaining = 0})
      : _store = {} {
    for (final review in reviews) {
      _store.putIfAbsent(review.bookId, () => <Review>[]).add(review);
    }
  }

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw Exception('boom');
    }
    return List<Review>.from(_store[bookId] ?? const []);
  }

  @override
  Future<void> addReview(Review review) async {
    _store.putIfAbsent(review.bookId, () => <Review>[]).add(review);
  }

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

Book _book(String id, String title) =>
    Book(id: id, title: title, author: '著者', isbn: 'isbn-$id');

Review _review(String id, String bookId, String text, DateTime createdAt) =>
    Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: text,
      createdAt: createdAt,
    );

List<Book> _books() => [
      _book('b1', '吾輩は猫である'),
      _book('b2', '坊っちゃん'),
    ];

List<Review> _reviews() => [
      _review('r1', 'b1', '面白い 猫の視点で描かれた話', DateTime(2026, 1, 5)),
      _review('r2', 'b2', '教師の日常を描いた作品', DateTime(2026, 2, 3)),
      _review('r3', 'b1', '文章が軽妙で読みやすい', DateTime(2026, 3, 1)),
    ];

Widget _buildSearchScreen({
  _FakeReviewRepository? reviewRepository,
  Widget Function(BuildContext, String)? reviewScreenBuilder,
}) {
  return MaterialApp(
    home: ReviewSearchScreen(
      bookRepository: _FakeBookRepository(_books()),
      reviewRepository: reviewRepository ?? _FakeReviewRepository(_reviews()),
      reviewScreenBuilder: reviewScreenBuilder,
    ),
  );
}

/// 非同期読込を決定的に進める（pumpAndSettle は使わない）
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(AppKeys.reviewSearchField), query);
  await tester.pump();
}

void main() {
  group('ReviewSearchScreen', () {
    testWidgets('本文の一部で1件だけ表示される', (tester) async {
      await tester.pumpWidget(_buildSearchScreen());
      await _settle(tester);

      await _type(tester, '軽妙');

      expect(find.byKey(AppKeys.reviewSearchRow('r3')), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchRow('r1')), findsNothing);
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('書名でもヒットする', (tester) async {
      await tester.pumpWidget(_buildSearchScreen());
      await _settle(tester);

      await _type(tester, '坊っちゃん');

      expect(find.byKey(AppKeys.reviewSearchRow('r2')), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchRow('r1')), findsNothing);
    });

    testWidgets('0件なら空状態が表示される', (tester) async {
      await tester.pumpWidget(_buildSearchScreen());
      await _settle(tester);

      await _type(tester, '存在しない検索語');

      expect(find.byKey(AppKeys.reviewSearchEmpty), findsOneWidget);
      expect(find.text('該当するレビューがありません'), findsOneWidget);
      expect(find.text('0件'), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchRow('r1')), findsNothing);
    });

    testWidgets('複数語は AND で絞り込まれる', (tester) async {
      await tester.pumpWidget(_buildSearchScreen());
      await _settle(tester);

      await _type(tester, '猫 視点');

      expect(find.byKey(AppKeys.reviewSearchRow('r1')), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchRow('r3')), findsNothing);
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('結果行に書名・日付・本文抜粋が表示される', (tester) async {
      await tester.pumpWidget(_buildSearchScreen());
      await _settle(tester);

      await _type(tester, '軽妙');

      final row = find.byKey(AppKeys.reviewSearchRow('r3'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('吾輩は猫である')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('2026/3/1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('文章が軽妙')),
        findsOneWidget,
      );
    });

    testWidgets('結果行タップで注入したレビュー画面へ遷移する', (tester) async {
      String? openedBookId;
      await tester.pumpWidget(
        _buildSearchScreen(
          reviewScreenBuilder: (context, bookId) {
            openedBookId = bookId;
            return Scaffold(body: Text('REVIEW_SCREEN:$bookId'));
          },
        ),
      );
      await _settle(tester);

      await _type(tester, '軽妙');
      await tester.tap(find.byKey(AppKeys.reviewSearchRow('r3')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(openedBookId, 'b1');
      expect(find.text('REVIEW_SCREEN:b1'), findsOneWidget);
    });

    testWidgets('読み込み失敗時はエラーと再試行が出て空状態は出ない', (tester) async {
      await tester.pumpWidget(
        _buildSearchScreen(
          reviewRepository:
              _FakeReviewRepository(_reviews(), failuresRemaining: 1),
        ),
      );
      await _settle(tester);

      expect(find.byKey(AppKeys.reviewSearchError), findsOneWidget);
      expect(find.text('レビューの読み込みに失敗しました'), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchRetry), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchEmpty), findsNothing);
    });

    testWidgets('再試行で成功したら結果が表示される', (tester) async {
      await tester.pumpWidget(
        _buildSearchScreen(
          reviewRepository:
              _FakeReviewRepository(_reviews(), failuresRemaining: 1),
        ),
      );
      await _settle(tester);
      expect(find.byKey(AppKeys.reviewSearchError), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.reviewSearchRetry));
      await _settle(tester);

      expect(find.byKey(AppKeys.reviewSearchError), findsNothing);
      expect(find.byKey(AppKeys.reviewSearchRow('r1')), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchRow('r2')), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchRow('r3')), findsOneWidget);
    });
  });

  group('BookshelfScreen からの導線', () {
    testWidgets('reviewRepository が null なら導線は出ず既存描画も壊れない',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(repository: _FakeBookRepository(_books())),
        ),
      );
      await _settle(tester);

      expect(find.byKey(const Key('screen_bookshelf')), findsOneWidget);
      expect(find.byKey(const Key('isbn_search_field')), findsOneWidget);
      expect(find.byKey(AppKeys.reviewSearchOpenButton), findsNothing);
    });

    testWidgets('reviewRepository があれば導線が出て検索画面へ遷移する',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(
            repository: _FakeBookRepository(_books()),
            reviewRepository: _FakeReviewRepository(_reviews()),
            reviewSearchBuilder: (context) =>
                const Scaffold(body: Text('STUB_SEARCH')),
          ),
        ),
      );
      await _settle(tester);

      final button = find.byKey(AppKeys.reviewSearchOpenButton);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('STUB_SEARCH'), findsOneWidget);
    });
  });
}
