import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';

Book readingBook() => const Book(
      id: 'b1',
      title: '試験の書',
      author: '著者',
      isbn: '9784000000000',
      pageCount: 300,
      readingStatus: ReadingStatus.reading,
      currentPage: 12,
    );

Book unreadBook() => const Book(
      id: 'b2',
      title: '未読の書',
      author: '著者',
      isbn: '9784000000001',
      pageCount: 200,
      readingStatus: ReadingStatus.unread,
      currentPage: 0,
    );

class RecordingBookRepository implements BookRepository {
  final List<Book> saved = [];
  @override
  Future<List<Book>> getBooks() async => [];
  @override
  Future<Book?> getBookById(String id) async => null;
  @override
  Future<Book?> findByIsbn(String isbn) async => null;
  @override
  Future<void> addBook(Book book) async {}
  @override
  Future<void> updateBook(Book book) async => saved.add(book);
  @override
  Future<void> removeBook(String id) async {}
}

class MockReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => const [];
  @override
  Future<void> addReview(Review review) async {}
  @override
  Future<void> updateReview(Review review) async {}
  @override
  Future<void> deleteReview(String id) async {}
}

class MockBookNoteRepository implements BookNoteRepository {
  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async => const [];
  @override
  Future<List<BookNote>> getAllNotes() async => const [];
  @override
  Future<void> addNote(BookNote note) async {}
  @override
  Future<void> updateNote(BookNote note) async {}
  @override
  Future<void> deleteNote(String id) async {}
  @override
  Future<void> deleteNotesByBookId(String bookId) async {}
}

Widget _wrap(BookDetailScreen screen) => MaterialApp(home: screen);

Future<RecordingBookRepository> _pump(
  WidgetTester tester, {
  Book? targetBook,
}) async {
  final repo = RecordingBookRepository();
  await tester.pumpWidget(_wrap(BookDetailScreen(
    book: targetBook ?? readingBook(),
    bookRepository: repo,
    reviewRepository: MockReviewRepository(),
    noteRepository: MockBookNoteRepository(),
  )));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('進行ページ管理 #89', () {
    testWidgets('読書中の本に「ページ更新」導線が表示される', (tester) async {
      await _pump(tester);
      expect(find.byKey(AppKeys.bookProgressEdit), findsOneWidget);
    });

    testWidgets('ダイアログでページ入力→保存でリポジトリに現在ページが永続化される',
        (tester) async {
      final repo = await _pump(tester);
      await tester.tap(find.byKey(AppKeys.bookProgressEdit));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.bookProgressInput), findsOneWidget);
      await tester.enterText(
          find.byKey(AppKeys.bookProgressInput), '45');
      await tester.tap(find.byKey(AppKeys.bookProgressSave));
      await tester.pumpAndSettle();
      expect(repo.saved.length, 1);
      expect(repo.saved.first.currentPage, 45);
      expect(repo.saved.first.readingStatus, ReadingStatus.reading);
    });

    testWidgets('総ページ以上の入力は読了に遷移し currentPage=pageCount',
        (tester) async {
      final repo = await _pump(tester);
      await tester.tap(find.byKey(AppKeys.bookProgressEdit));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(AppKeys.bookProgressInput), '300');
      await tester.tap(find.byKey(AppKeys.bookProgressSave));
      await tester.pumpAndSettle();
      expect(repo.saved.first.readingStatus, ReadingStatus.finished);
      expect(repo.saved.first.currentPage, 300);
      expect(repo.saved.first.finishedAt, isNotNull);
    });

    testWidgets('非数値入力では保存せずエラー表示', (tester) async {
      final repo = await _pump(tester);
      await tester.tap(find.byKey(AppKeys.bookProgressEdit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AppKeys.bookProgressInput), 'abc');
      await tester.tap(find.byKey(AppKeys.bookProgressSave));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.byKey(AppKeys.bookProgressInput), findsOneWidget);
    });

    testWidgets('未読の本では導線を表示せず、読書開始ボタンで読書中に遷移',
        (tester) async {
      final repo = await _pump(
          tester,
          targetBook: const Book(
            id: 'b2',
            title: '未読の書',
            author: '著者',
            isbn: '9784000000001',
            pageCount: 200,
            readingStatus: ReadingStatus.unread,
            currentPage: 0,
          ));
      expect(find.byKey(AppKeys.bookProgressEdit), findsNothing);
      await tester.tap(find.byKey(AppKeys.bookProgressStart));
      await tester.pumpAndSettle();
      expect(repo.saved.first.readingStatus, ReadingStatus.reading);
      expect(repo.saved.first.currentPage, 0);
    });
  });
}