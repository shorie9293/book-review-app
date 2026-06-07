import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_card.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_form.dart';

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
      if (index != -1) {
        list[index] = review;
      }
    }
  }

  @override
  Future<void> deleteReview(String id) async {
    for (final list in _store.values) {
      list.removeWhere((r) => r.id == id);
    }
  }
}

/// 遅延付きモックリポジトリ（ローディング状態のテスト用）
class DelayedMockReviewRepository implements ReviewRepository {
  final Duration delay;
  final List<Review> reviews;

  DelayedMockReviewRepository({this.delay = const Duration(seconds: 1), this.reviews = const []});

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async {
    await Future.delayed(delay);
    return reviews;
  }

  @override
  Future<void> addReview(Review review) async {
    await Future.delayed(delay);
  }

  @override
  Future<void> updateReview(Review review) async {
    await Future.delayed(delay);
  }

  @override
  Future<void> deleteReview(String id) async {
    await Future.delayed(delay);
  }
}

Widget _buildTestApp(String bookId, ReviewRepository repository) {
  return MaterialApp(
    home: ReviewScreen(
      bookId: bookId,
      reviewRepository: repository,
    ),
  );
}

Review _createReview({
  String id = 'review-1',
  String bookId = 'book-1',
  int rating = 4,
  String text = '良い本でした',
  DateTime? createdAt,
}) {
  return Review(
    id: id,
    bookId: bookId,
    rating: rating,
    text: text,
    createdAt: createdAt ?? DateTime(2024, 1, 15),
  );
}

void main() {
  group('ReviewScreen', () {
    testWidgets('1. shows empty state when no reviews', (tester) async {
      final repository = MockReviewRepository();
      await tester.pumpWidget(_buildTestApp('book-1', repository));

      // Wait for async loading to complete
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_review')), findsOneWidget);
      expect(find.byKey(const Key('review_empty_state')), findsOneWidget);
      expect(find.text('レビューはまだありません'), findsOneWidget);
    });

    testWidgets('2. displays reviews in a list', (tester) async {
      final repository = MockReviewRepository();
      await repository.addReview(_createReview(
        id: 'review-1',
        text: '素晴らしい本です',
      ));
      await repository.addReview(_createReview(
        id: 'review-2',
        text: '面白かったです',
        rating: 5,
      ));

      await tester.pumpWidget(_buildTestApp('book-1', repository));
      await tester.pumpAndSettle();

      // Both reviews should be visible
      expect(find.text('素晴らしい本です'), findsOneWidget);
      expect(find.text('面白かったです'), findsOneWidget);

      // Review cards should be rendered
      expect(find.byType(ReviewCard), findsNWidgets(2));
    });

    testWidgets('3. shows loading state while fetching', (tester) async {
      final repository = DelayedMockReviewRepository(delay: const Duration(seconds: 5));

      await tester.pumpWidget(_buildTestApp('book-1', repository));

      // After pump, the async load hasn't completed yet
      expect(find.byKey(const Key('review_loading_state')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let the pending timer complete to avoid "timer still pending" error
      await tester.pump(Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('4. add button opens form dialog', (tester) async {
      final repository = MockReviewRepository();
      await tester.pumpWidget(_buildTestApp('book-1', repository));
      await tester.pumpAndSettle();

      // Tap the FAB
      await tester.tap(find.byKey(const Key('review_add_fab')));
      await tester.pumpAndSettle();

      // ReviewForm should appear
      expect(find.byType(ReviewForm), findsOneWidget);
      expect(find.byKey(const Key('review_form')), findsOneWidget);
    });

    testWidgets('5. can add review via form', (tester) async {
      final repository = MockReviewRepository();
      await tester.pumpWidget(_buildTestApp('book-1', repository));
      await tester.pumpAndSettle();

      // Open add dialog via FAB
      await tester.tap(find.byKey(const Key('review_add_fab')));
      await tester.pumpAndSettle();

      // Verify form is shown
      expect(find.byType(ReviewForm), findsOneWidget);

      // Tap a star (star index 3 = rating 4)
      await tester.tap(find.byKey(const Key('review_form_star_3')));
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(
        find.byKey(const Key('review_form_text_field')),
        'とても良い本でした',
      );
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.byKey(const Key('review_form_save_button')));
      await tester.pumpAndSettle();

      // Review should appear in the list
      expect(find.text('とても良い本でした'), findsOneWidget);
      expect(find.byType(ReviewCard), findsOneWidget);
    });

    testWidgets('6. can delete review', (tester) async {
      final repository = MockReviewRepository();
      await repository.addReview(_createReview(
        id: 'review-1',
        text: '削除するレビュー',
      ));

      await tester.pumpWidget(_buildTestApp('book-1', repository));
      await tester.pumpAndSettle();

      // Verify review is present
      expect(find.text('削除するレビュー'), findsOneWidget);
      expect(find.byType(ReviewCard), findsOneWidget);

      // Tap delete button on the card
      await tester.tap(find.byKey(const Key('review_card_delete_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('レビューを削除'), findsOneWidget);
      expect(find.text('このレビューを削除してもよろしいですか？'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.byKey(const Key('review_delete_confirm_button')));
      await tester.pumpAndSettle();

      // Review should be removed
      expect(find.text('削除するレビュー'), findsNothing);
      expect(find.byType(ReviewCard), findsNothing);

      // Empty state should show
      expect(find.byKey(const Key('review_empty_state')), findsOneWidget);
    });

    testWidgets('7. can edit review', (tester) async {
      final repository = MockReviewRepository();
      await repository.addReview(_createReview(
        id: 'review-2',
        text: '編集前のレビュー',
        rating: 3,
      ));

      await tester.pumpWidget(_buildTestApp('book-1', repository));
      await tester.pumpAndSettle();

      // Verify review is present
      expect(find.text('編集前のレビュー'), findsOneWidget);

      // Tap edit button on the card
      await tester.tap(find.byKey(const Key('review_card_edit_button')));
      await tester.pumpAndSettle();

      // ReviewForm should appear with pre-populated text
      expect(find.byType(ReviewForm), findsOneWidget);
      // The existing text should be shown in the text field
      expect(find.text('編集前のレビュー'), findsWidgets);

      // Clear the existing text and enter new text
      await tester.enterText(
        find.byKey(const Key('review_form_text_field')),
        '編集後のレビュー',
      );
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.byKey(const Key('review_form_save_button')));
      await tester.pumpAndSettle();

      // Updated review should appear, old text should be gone
      expect(find.text('編集後のレビュー'), findsOneWidget);
      expect(find.text('編集前のレビュー'), findsNothing);
      expect(find.byType(ReviewCard), findsOneWidget);
    });
  });
}
