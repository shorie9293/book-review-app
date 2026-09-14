import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';

class StubReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => [];

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

Future<void> pumpReview(
  WidgetTester tester, {
  BookNoteRepository? noteRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReviewScreen(
        bookId: 'book-1',
        reviewRepository: StubReviewRepository(),
        noteRepository: noteRepository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ReviewScreen の読書メモ導線', () {
    testWidgets('noteRepositoryが無ければ導線を表示しない', (tester) async {
      await pumpReview(tester);
      expect(find.byKey(const Key('open_notes_button')), findsNothing);
    });

    testWidgets('noteRepositoryがあれば導線を表示する', (tester) async {
      await pumpReview(tester, noteRepository: InMemoryBookNoteRepository());
      expect(find.byKey(const Key('open_notes_button')), findsOneWidget);
    });

    testWidgets('導線をタップすると読書メモ画面へ遷移する', (tester) async {
      final repository = InMemoryBookNoteRepository();
      await repository.addNote(BookNote(
        id: 'n1',
        bookId: 'book-1',
        content: '遷移先のメモ',
        createdAt: DateTime(2026, 1, 1),
      ));
      await pumpReview(tester, noteRepository: repository);

      await tester.tap(find.byKey(const Key('open_notes_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_book_notes')), findsOneWidget);
      expect(find.text('遷移先のメモ'), findsOneWidget);
    });
  });
}
