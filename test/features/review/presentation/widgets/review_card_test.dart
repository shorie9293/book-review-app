import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_card.dart';

void main() {
  group('ReviewCard', () {
    final review = Review(
      id: '1',
      bookId: 'book1',
      rating: 4,
      text: 'Great book! Highly recommend.',
      createdAt: DateTime(2025, 3, 15),
    );

    Widget buildCard({required Review review, required VoidCallback onDelete, required VoidCallback onEdit}) {
      return MaterialApp(
        home: Scaffold(
          body: ReviewCard(
            review: review,
            onDelete: onDelete,
            onEdit: onEdit,
          ),
        ),
      );
    }

    testWidgets('displays correct number of filled stars based on rating',
        (tester) async {
      await tester.pumpWidget(buildCard(
        review: review,
        onDelete: () {},
        onEdit: () {},
      ));

      final starsFinder = find.text('★★★★☆');
      expect(starsFinder, findsOneWidget);
    });

    testWidgets('displays the review text content', (tester) async {
      await tester.pumpWidget(buildCard(
        review: review,
        onDelete: () {},
        onEdit: () {},
      ));

      final textFinder = find.text('Great book! Highly recommend.');
      expect(textFinder, findsOneWidget);
    });

    testWidgets('displays the date', (tester) async {
      await tester.pumpWidget(buildCard(
        review: review,
        onDelete: () {},
        onEdit: () {},
      ));

      final dateFinder = find.text('2025/3/15');
      expect(dateFinder, findsOneWidget);
    });

    testWidgets('calls onDelete callback when delete button is tapped',
        (tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(buildCard(
        review: review,
        onDelete: () => deleteCalled = true,
        onEdit: () {},
      ));

      final deleteButton = find.byKey(const Key('review_card_delete_button'));
      expect(deleteButton, findsOneWidget);

      await tester.tap(deleteButton);
      expect(deleteCalled, isTrue);
    });
  });
}
