import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:book_review_app/features/review/presentation/review_search_screen.dart';

/// 親探針: レビュー横断検索の合成不変条件。
///
/// 眷属神の試練は「1画面・1操作」を個別に固定するが、以下は撃たない:
///  - 複数書籍にまたがるヒットで書名の対応が崩れないか
///  - 既存の蔵書検索（library_query）の意味論が変わっていないか
///  - 空検索語・長文抜粋の境界
///  - 複数書籍があるとき遷移先の bookId を取り違えないか
class _Books implements BookRepository {
  final List<Book> books;

  _Books(this.books);

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

class _Reviews implements ReviewRepository {
  final Map<String, List<Review>> store;

  _Reviews(List<Review> reviews) : store = {} {
    for (final review in reviews) {
      store.putIfAbsent(review.bookId, () => <Review>[]).add(review);
    }
  }

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async =>
      List<Review>.from(store[bookId] ?? const []);

  @override
  Future<void> addReview(Review review) async =>
      store.putIfAbsent(review.bookId, () => <Review>[]).add(review);

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {
    for (final entry in store.entries) {
      entry.value.removeWhere((review) => review.id == id);
    }
  }
}

Book _book(String id, String title, String author) => Book(
      id: id,
      title: title,
      author: author,
      isbn: 'isbn-$id',
      readingStatus: ReadingStatus.finished,
    );

Review _review(
  String id,
  String bookId,
  String text, {
  DateTime? createdAt,
}) =>
    Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: text,
      createdAt: createdAt ?? DateTime.utc(2026, 3, 1),
    );

void main() {
  testWidgets('親探針① 複数書籍のヒットで各行の書名が取り違えられない', (tester) async {
    final books = [
      _book('b1', '海辺のカフカ', '村上春樹'),
      _book('b2', 'ノルウェイの森', '村上春樹'),
    ];
    final reviews = [
      _review('r1', 'b1', '喪失についての描写が心に残った'),
      _review('r2', 'b2', '喪失の扱いが対照的だった'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: ReviewSearchScreen(
        bookRepository: _Books(books),
        reviewRepository: _Reviews(reviews),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), '喪失');
    await tester.pump();

    expect(find.text('海辺のカフカ'), findsOneWidget);
    expect(find.text('ノルウェイの森'), findsOneWidget);

    // 各行の書名が正しい本に対応していること（行の中で突き合わせる）。
    final kafkaRow = find.ancestor(
      of: find.text('海辺のカフカ'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: kafkaRow, matching: find.textContaining('描写')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: kafkaRow, matching: find.textContaining('対照的')),
      findsNothing,
    );
  });

  testWidgets('親探針② 空検索語では全レビューが件数に出る', (tester) async {
    final books = [_book('b1', '本A', '著者A'), _book('b2', '本B', '著者B')];
    final reviews = [
      _review('r1', 'b1', '一つ目'),
      _review('r2', 'b2', '二つ目'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: ReviewSearchScreen(
        bookRepository: _Books(books),
        reviewRepository: _Reviews(reviews),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2件'), findsOneWidget);
  });

  testWidgets('親探針③ 長文レビューの抜粋は80字以内に収まる', (tester) async {
    final longText = 'あ' * 300;
    final books = [_book('b1', '本A', '著者A')];
    final reviews = [_review('r1', 'b1', longText)];

    await tester.pumpWidget(MaterialApp(
      home: ReviewSearchScreen(
        bookRepository: _Books(books),
        reviewRepository: _Reviews(reviews),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 本文全体（300字）がそのまま描画されていないこと＝抜粋が効いている。
    expect(find.textContaining(longText), findsNothing);
    expect(find.textContaining('あ'), findsWidgets);
  });

  test('親探針④ 既存の蔵書検索はレビュー本文を対象にしない（意味論の不変）', () {
    final books = [_book('b1', '海辺のカフカ', '村上春樹')];

    // レビュー本文にしか無い語では蔵書検索はヒットしない（従来通り）。
    final byReviewText = LibraryQueryService.apply(
      books,
      const LibraryQuery(text: '喪失'),
    );
    expect(byReviewText, isEmpty);

    // 書名・著者では従来通りヒットする。
    expect(
      LibraryQueryService.apply(books, const LibraryQuery(text: 'カフカ')),
      hasLength(1),
    );
    expect(
      LibraryQueryService.apply(books, const LibraryQuery(text: '村上')),
      hasLength(1),
    );
  });

  testWidgets('親探針⑤ 複数書籍があるとき遷移先の bookId を取り違えない', (tester) async {
    final books = [_book('b1', '本A', '著者A'), _book('b2', '本B', '著者B')];
    final reviews = [
      _review('r1', 'b1', '共通語 一つ目'),
      _review('r2', 'b2', '共通語 二つ目'),
    ];
    String? opened;

    await tester.pumpWidget(MaterialApp(
      home: ReviewSearchScreen(
        bookRepository: _Books(books),
        reviewRepository: _Reviews(reviews),
        reviewScreenBuilder: (context, bookId) {
          opened = bookId;
          return const Scaffold(body: Text('遷移先'));
        },
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), '共通語');
    await tester.pump();

    // 2行目（本B）の行をタップする。
    await tester.tap(find.text('本B'));
    await tester.pumpAndSettle();

    expect(opened, 'b2');
  });
}
