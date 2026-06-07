import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_form.dart';

void main() {
  group('ReviewForm', () {
    const testBookId = 'book-1';

    Widget buildForm({
      String bookId = testBookId,
      Review? review,
      required void Function(Review) onSave,
      required VoidCallback onCancel,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ReviewForm(
            bookId: bookId,
            onSave: onSave,
            onCancel: onCancel,
            review: review,
          ),
        ),
      );
    }

    testWidgets('displays 5 tappable stars (all empty when rating=0 initially)',
        (tester) async {
      await tester.pumpWidget(buildForm(
        onSave: (_) {},
        onCancel: () {},
      ));

      // Verify the form widget exists
      expect(find.byKey(const Key('review_form')), findsOneWidget);

      // Verify all 5 stars are present
      for (int i = 0; i < 5; i++) {
        expect(find.byKey(Key('review_form_star_$i')), findsOneWidget);
      }

      // Initially all stars should be empty (star_border icons)
      final starIcons = find.byIcon(Icons.star_border);
      expect(starIcons, findsNWidgets(5));

      // No filled stars initially
      final filledStars = find.byIcon(Icons.star);
      expect(filledStars, findsNothing);
    });

    testWidgets('updates displayed rating when a star is tapped',
        (tester) async {
      await tester.pumpWidget(buildForm(
        onSave: (_) {},
        onCancel: () {},
      ));

      // Tap the 3rd star (index 2, which gives rating=3)
      await tester.tap(find.byKey(const Key('review_form_star_2')));
      await tester.pumpAndSettle();

      // Should have 3 filled stars and 2 empty stars
      final filledStars = find.byIcon(Icons.star);
      expect(filledStars, findsNWidgets(3));

      final emptyStars = find.byIcon(Icons.star_border);
      expect(emptyStars, findsNWidgets(2));
    });

    testWidgets('shows text field for entering review content', (tester) async {
      await tester.pumpWidget(buildForm(
        onSave: (_) {},
        onCancel: () {},
      ));

      // Verify the text field exists
      final textField = find.byKey(const Key('review_form_text_field'));
      expect(textField, findsOneWidget);

      // Verify it's an editable text field (TextFormField or TextField)
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.maxLines, 5);
      expect(textFieldWidget.maxLength, 500);
      expect(textFieldWidget.keyboardType, TextInputType.multiline);

      // Enter text and verify it appears
      await tester.enterText(textField, 'Great book! Highly recommended.');
      expect(find.text('Great book! Highly recommended.'), findsOneWidget);
    });

    testWidgets('calls onSave with correct Review data when save button is pressed',
        (tester) async {
      Review? savedReview;

      await tester.pumpWidget(buildForm(
        onSave: (review) => savedReview = review,
        onCancel: () {},
      ));

      // Set rating by tapping the 4th star (index 3, rating=4)
      await tester.tap(find.byKey(const Key('review_form_star_3')));
      await tester.pumpAndSettle();

      // Enter review text
      await tester.enterText(
        find.byKey(const Key('review_form_text_field')),
        'A wonderful read!',
      );

      // Tap Save button
      await tester.tap(find.byKey(const Key('review_form_save_button')));
      await tester.pumpAndSettle();

      // Verify onSave was called
      expect(savedReview, isNotNull);

      // Verify the review has correct data
      expect(savedReview!.bookId, testBookId);
      expect(savedReview!.rating, 4);
      expect(savedReview!.text, 'A wonderful read!');
      expect(savedReview!.id, isNotEmpty);
      expect(savedReview!.createdAt, isNotNull);
    });

    testWidgets('pre-populates rating and text when review is provided (edit mode)',
        (tester) async {
      final existingReview = Review(
        id: 'existing-1',
        bookId: testBookId,
        rating: 3,
        text: 'An okay book.',
        createdAt: DateTime(2025, 5, 1),
      );

      await tester.pumpWidget(buildForm(
        review: existingReview,
        onSave: (_) {},
        onCancel: () {},
      ));

      // Verify text field is pre-populated
      final textField = find.byKey(const Key('review_form_text_field'));
      expect((tester.widget<TextField>(textField)).controller?.text,
          'An okay book.');

      // Verify 3 stars are filled (pre-populated rating)
      final filledStars = find.byIcon(Icons.star);
      expect(filledStars, findsNWidgets(3));

      final emptyStars = find.byIcon(Icons.star_border);
      expect(emptyStars, findsNWidgets(2));
    });

    testWidgets('calls onCancel when cancel button is tapped', (tester) async {
      bool cancelCalled = false;

      await tester.pumpWidget(buildForm(
        onSave: (_) {},
        onCancel: () => cancelCalled = true,
      ));

      await tester.tap(find.byKey(const Key('review_form_cancel_button')));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });
  });
}
