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

Book bookWith({String? location}) => Book(
      id: 'b1',
      title: 'テスト駆動開発',
      author: 'Kent Beck',
      isbn: '978-4-274-21788-3',
      location: location,
    );

Future<RecordingBookRepository> pumpDetail(
  WidgetTester tester, {
  String? location,
}) async {
  // 蔵書詳細は縦に長い。所在欄は下部にあるため縦長のビューポートで描画する。
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final repository = RecordingBookRepository();
  await tester.pumpWidget(MaterialApp(
    home: BookDetailScreen(
      book: bookWith(location: location),
      bookRepository: repository,
      reviewRepository: MockReviewRepository(),
      noteRepository: MockBookNoteRepository(),
    ),
  ));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> openDialog(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(AppKeys.locationEditButton));
  await tester.tap(find.byKey(AppKeys.locationEditButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('所在未設定の本は「所在未設定」を表示する（貸出リポジトリ未指定でも出る）',
      (tester) async {
    await pumpDetail(tester);

    expect(find.byKey(AppKeys.locationSection), findsOneWidget);
    expect(find.text('所在未設定'), findsOneWidget);
    expect(find.byKey(AppKeys.locationValue), findsNothing);
  });

  testWidgets('編集→保存で updateBook に到達し、再描画で新しい所在が出る', (tester) async {
    final repository = await pumpDetail(tester);

    await openDialog(tester);
    expect(find.byKey(AppKeys.locationInput), findsOneWidget);

    await tester.enterText(find.byKey(AppKeys.locationInput), ' 居間の本棚 2段目 ');
    await tester.tap(find.byKey(AppKeys.locationSave));
    await tester.pumpAndSettle();

    expect(repository.updated, hasLength(1));
    expect(repository.updated.single.id, 'b1');
    expect(repository.updated.single.location, '居間の本棚 2段目');

    final value = tester.widget<Text>(find.byKey(AppKeys.locationValue));
    expect(value.data, '居間の本棚 2段目');
    expect(find.text('所在未設定'), findsNothing);
  });

  testWidgets('空入力は保存されず、エラーを表示してダイアログが閉じない', (tester) async {
    final repository = await pumpDetail(tester);

    await openDialog(tester);
    await tester.enterText(find.byKey(AppKeys.locationInput), '   ');
    await tester.tap(find.byKey(AppKeys.locationSave));
    await tester.pumpAndSettle();

    expect(repository.updated, isEmpty);
    expect(find.text('所在を入力してください'), findsOneWidget);
    expect(find.byKey(AppKeys.locationInput), findsOneWidget);
  });

  testWidgets('40文字超の入力は保存されずエラーを表示する', (tester) async {
    final repository = await pumpDetail(tester);

    await openDialog(tester);
    await tester.enterText(find.byKey(AppKeys.locationInput), 'あ' * 41);
    await tester.tap(find.byKey(AppKeys.locationSave));
    await tester.pumpAndSettle();

    expect(repository.updated, isEmpty);
    expect(find.text('所在は40文字以内で入力してください'), findsOneWidget);
  });

  testWidgets('現在値ありのとき「所在を消す」で null に戻る（リポジトリ到達）', (tester) async {
    final repository = await pumpDetail(tester, location: '書斎の棚');

    expect(find.byKey(AppKeys.locationValue), findsOneWidget);

    await openDialog(tester);
    expect(find.byKey(AppKeys.locationClear), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.locationClear));
    await tester.pumpAndSettle();

    expect(repository.updated, hasLength(1));
    expect(repository.updated.single.location, isNull);
    expect(find.text('所在未設定'), findsOneWidget);
    expect(find.byKey(AppKeys.locationValue), findsNothing);
  });

  testWidgets('所在未設定のときは「所在を消す」ボタンを出さない', (tester) async {
    await pumpDetail(tester);

    await openDialog(tester);
    expect(find.byKey(AppKeys.locationClear), findsNothing);
  });
}
