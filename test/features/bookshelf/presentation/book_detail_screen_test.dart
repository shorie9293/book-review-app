import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';

/// テスト用モック: BookRepository
class MockBookRepository implements BookRepository {
  @override
  Future<List<Book>> getBooks() async => [];

  @override
  Future<Book?> getBookById(String id) async => null;

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async {}

  @override
  Future<void> updateBook(Book book) async {}

  @override
  Future<void> removeBook(String id) async {}
}

/// テスト用モック: ReviewRepository
class MockReviewRepository implements ReviewRepository {
  final List<Review> reviews;
  MockReviewRepository({this.reviews = const []});

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => reviews;

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

/// テスト用モック: BookNoteRepository
class MockBookNoteRepository implements BookNoteRepository {
  final List<BookNote> notes;
  MockBookNoteRepository({this.notes = const []});

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async => notes;

  @override
  Future<List<BookNote>> getAllNotes() async => notes;

  @override
  Future<void> addNote(BookNote note) async {}

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> deleteNotesByBookId(String bookId) async {}
}

Book book({
  ReadingStatus status = ReadingStatus.unread,
  int currentPage = 0,
  int? pageCount = 300,
  DateTime? finishedAt,
  String? coverImageUrl,
}) =>
    Book(
      id: 'b1',
      title: 'テスト駆動開発',
      author: 'Kent Beck',
      isbn: '978-4-274-21788-3',
      coverImageUrl: coverImageUrl,
      pageCount: pageCount,
      readingStatus: status,
      currentPage: currentPage,
      finishedAt: finishedAt,
    );

Review review(String id, {int rating = 4}) => Review(
      id: id,
      bookId: 'b1',
      rating: rating,
      text: '良書だった',
      createdAt: DateTime(2026, 1, 1),
    );

BookNote note(
  String id, {
  NoteKind kind = NoteKind.memo,
  bool isFavorite = false,
  int? pageNumber,
}) =>
    BookNote(
      id: id,
      bookId: 'b1',
      kind: kind,
      content: 'とても良い着想',
      pageNumber: pageNumber,
      createdAt: DateTime(2026, 1, 2),
      isFavorite: isFavorite,
    );

Widget wrap(BookDetailScreen screen) => MaterialApp(home: screen);

Future<void> pumpScreen(
  WidgetTester tester, {
  List<Review> reviews = const [],
  List<BookNote> notes = const [],
  bool withNotes = true,
  Book? targetBook,
}) async {
  await tester.pumpWidget(wrap(BookDetailScreen(
    book: targetBook ?? book(),
    bookRepository: MockBookRepository(),
    reviewRepository: MockReviewRepository(reviews: reviews),
    noteRepository: withNotes ? MockBookNoteRepository(notes: notes) : null,
  )));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('サマリー表示: 評価平均・レビュー件数・メモ/引用・お気に入り・最終活動日',
      (tester) async {
    await pumpScreen(
      tester,
      reviews: [
        review('r1', rating: 4),
        review('r2', rating: 2),
      ],
      notes: [
        note('n1', kind: NoteKind.memo, isFavorite: true),
        note('n2', kind: NoteKind.quote),
      ],
    );

    final summary = find.byKey(const Key('book_detail_summary'));
    expect(summary, findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: summary, matching: find.byType(Text)).first,
    );
    expect(text, isNotNull);
    // サマリーカード内に★評価・レビュー件数・メモ/引用・お気に入り・最終活動が表示される
    expect(
      find.descendant(of: summary, matching: find.textContaining('★')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.textContaining('レビュー')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: summary, matching: find.textContaining('お気に入り')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.textContaining('最終活動')),
      findsOneWidget,
    );
  });

  testWidgets('ヘッダー: タイトル・著者が表示される', (tester) async {
    await pumpScreen(tester);
    expect(find.text('テスト駆動開発'), findsOneWidget);
    expect(find.text('Kent Beck'), findsOneWidget);
  });

  testWidgets('レビュー空状態', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('book_detail_empty_reviews')), findsOneWidget);
  });

  testWidgets('レビュー有り: 行が表示される', (tester) async {
    await pumpScreen(tester, reviews: [review('r1'), review('r2')]);
    expect(
        find.byKey(const Key('book_detail_review_row_r1')), findsOneWidget);
    expect(
        find.byKey(const Key('book_detail_review_row_r2')), findsOneWidget);
    expect(find.byKey(const Key('book_detail_empty_reviews')), findsNothing);


    expect(find.text('良書だった'), findsNWidgets(2));
  });

  testWidgets('メモ空状態', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('book_detail_empty_notes')), findsOneWidget);
  });

  testWidgets('メモ有り: 行が表示される（kindラベル・ページ番号）', (tester) async {
    await pumpScreen(tester, notes: [
      note('n1', kind: NoteKind.quote, pageNumber: 42),
      note('n2', kind: NoteKind.memo),
    ]);
    // 進行ページ管理(#89)でボタンが増え、メモ行はListViewの遅延描画範囲外に
    // なり得るためスクロールしてから検証する。
    await tester.scrollUntilVisible(
      find.byKey(const Key('book_detail_note_row_n1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('book_detail_note_row_n1')), findsOneWidget);
    expect(find.byKey(const Key('book_detail_note_row_n2')), findsOneWidget);
    expect(find.byKey(const Key('book_detail_empty_notes')), findsNothing);
    expect(find.text('p.42'), findsOneWidget);
  });

  testWidgets('お気に入り件数がサマリーに表示される', (tester) async {
    await pumpScreen(tester, notes: [
      note('n1', isFavorite: true),
      note('n2'),
      note('n3', isFavorite: true),
    ]);
    expect(find.textContaining('お気に入り 2件'), findsOneWidget);
  });

  testWidgets('進捗ラベル: 読書中 12/300ページ', (tester) async {
    await pumpScreen(
      tester,
      targetBook: book(
        status: ReadingStatus.reading,
        currentPage: 12,
        pageCount: 300,
      ),
    );
    expect(find.text('読書中 12/300ページ'), findsOneWidget);
  });

  testWidgets('レビュー導線ボタンでReviewScreenへpush', (tester) async {
    await pumpScreen(tester, reviews: [review('r1')]);
    expect(find.byKey(const Key('book_detail_open_reviews')),
        findsOneWidget);
    expect(find.byType(BookDetailScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('book_detail_open_reviews')));
    await tester.pumpAndSettle();

    // ReviewScreenへ遷移した（AppBarタイトルがレビュー画面のものに変わる）
    expect(find.text('レビュー'), findsOneWidget);
    // レビュー内容は詳細画面から引き継がれて表示される
    expect(find.text('良書だった'), findsOneWidget);
  });

  testWidgets('カバー無しはプレースホルダー表示', (tester) async {
    await pumpScreen(tester, targetBook: book(coverImageUrl: null));
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
  });

  testWidgets('noteRepository未指定でもメモ空状態で表示される', (tester) async {
    await pumpScreen(tester, withNotes: false);
    expect(find.byKey(const Key('book_detail_empty_notes')), findsOneWidget);
    expect(find.byKey(const Key('book_detail_open_notes')), findsNothing);
  });
}

/// 進行ページ管理（#89）試練用: updateBook を記録するモック。
class RecordingBookRepository extends MockBookRepository {
  final List<Book> saved = [];
  @override
  Future<void> updateBook(Book book) async {
    saved.add(book);
  }
}

/// 進行ページ管理（#89）試練は book_progress_update_test.dart へ。
