import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';

/// updateBook の呼び出しを記録するフェイク。
class RecordingBookRepository implements BookRepository {
  final List<Book> updated = [];

  @override
  Future<List<Book>> getBooks() async => [];

  @override
  Future<Book?> getBookById(String id) async => null;

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async {}

  @override
  Future<void> updateBook(Book book) async => updated.add(book);

  @override
  Future<void> removeBook(String id) async {}
}

class MockReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => [];

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

class MockBookNoteRepository implements BookNoteRepository {
  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async => [];

  @override
  Future<List<BookNote>> getAllNotes() async => [];

  @override
  Future<void> addNote(BookNote note) async {}

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> deleteNotesByBookId(String bookId) async {}
}

Book bookWith({List<String> genres = const []}) => Book(
      id: 'b1',
      title: 'テスト駆動開発',
      author: 'Kent Beck',
      isbn: '978-4-274-21788-3',
      genres: genres,
    );

Future<RecordingBookRepository> pumpDetail(
  WidgetTester tester, {
  List<String> genres = const [],
}) async {
  // 蔵書詳細は縦に長い。ジャンル欄は最下部にあるため縦長のビューポートで描画する。
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final repository = RecordingBookRepository();
  await tester.pumpWidget(MaterialApp(
    home: BookDetailScreen(
      book: bookWith(genres: genres),
      bookRepository: repository,
      reviewRepository: MockReviewRepository(),
      noteRepository: MockBookNoteRepository(),
    ),
  ));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('ジャンル未設定の本は「ジャンル未設定」を表示し、追加ボタンがある',
      (tester) async {
    await pumpDetail(tester);
    expect(find.text('ジャンル未設定'), findsOneWidget);
    expect(find.byKey(AppKeys.genreAdd), findsOneWidget);
  });

  testWidgets('ジャンル付きの本はチップを表示する', (tester) async {
    await pumpDetail(tester, genres: ['小説', '技術書']);
    expect(find.byKey(AppKeys.genreChip('小説')), findsOneWidget);
    expect(find.byKey(AppKeys.genreChip('技術書')), findsOneWidget);
    expect(find.text('ジャンル未設定'), findsNothing);
  });

  testWidgets('追加ダイアログで入力→保存すると updateBook に genres が渡る',
      (tester) async {
    final repository = await pumpDetail(tester, genres: ['小説']);

    await tester.tap(find.byKey(AppKeys.genreAdd));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.genreDialog), findsOneWidget);

    await tester.enterText(find.byKey(AppKeys.genreInput), '技術書');
    await tester.tap(find.byKey(AppKeys.genreSave));
    await tester.pumpAndSettle();

    expect(repository.updated, hasLength(1));
    expect(repository.updated.single.id, 'b1');
    expect(repository.updated.single.genres, ['小説', '技術書']);
    // 画面にも反映される
    expect(find.byKey(AppKeys.genreChip('技術書')), findsOneWidget);
  });

  testWidgets('空白のみの入力は保存されず、エラーを表示する', (tester) async {
    final repository = await pumpDetail(tester);

    await tester.tap(find.byKey(AppKeys.genreAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.genreInput), '   ');
    await tester.tap(find.byKey(AppKeys.genreSave));
    await tester.pumpAndSettle();

    expect(repository.updated, isEmpty);
    expect(find.text('ジャンル名を入力してください'), findsOneWidget);
  });

  testWidgets('既存と同名（正規化後）の入力は保存されず、エラーを表示する',
      (tester) async {
    final repository = await pumpDetail(tester, genres: ['小説']);

    await tester.tap(find.byKey(AppKeys.genreAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.genreInput), ' 小説 ');
    await tester.tap(find.byKey(AppKeys.genreSave));
    await tester.pumpAndSettle();

    expect(repository.updated, isEmpty);
    expect(find.textContaining('既に登録されています'), findsOneWidget);
  });

  testWidgets('チップの削除ボタンで updateBook が呼ばれ、画面から消える', (tester) async {
    final repository = await pumpDetail(tester, genres: ['小説', '技術書']);

    await tester.tap(find.byKey(AppKeys.genreRemove('小説')));
    await tester.pumpAndSettle();

    expect(repository.updated, hasLength(1));
    expect(repository.updated.single.genres, ['技術書']);
    expect(find.byKey(AppKeys.genreChip('小説')), findsNothing);
    expect(find.byKey(AppKeys.genreChip('技術書')), findsOneWidget);
  });

  testWidgets('最後のジャンルを削除すると空リストで永続化される', (tester) async {
    final repository = await pumpDetail(tester, genres: ['小説']);

    await tester.tap(find.byKey(AppKeys.genreRemove('小説')));
    await tester.pumpAndSettle();

    expect(repository.updated.single.genres, isEmpty);
    expect(find.text('ジャンル未設定'), findsOneWidget);
  });
}
