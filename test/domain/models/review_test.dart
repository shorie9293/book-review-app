import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/review.dart';

void main() {
  group('Review', () {
    test('should create with required fields', () {
      final now = DateTime(2026, 5, 19);
      final review = Review(
        id: 'rev-1',
        bookId: 'book-123',
        rating: 4,
        text: 'とても参考になりました',
        createdAt: now,
      );

      expect(review.id, 'rev-1');
      expect(review.bookId, 'book-123');
      expect(review.rating, 4);
      expect(review.text, 'とても参考になりました');
      expect(review.createdAt, now);
    });

    test('should default updatedAt to createdAt', () {
      final now = DateTime(2026, 5, 19);
      final review = Review(
        id: 'rev-1',
        bookId: 'book-123',
        rating: 4,
        text: 'テスト',
        createdAt: now,
      );

      expect(review.updatedAt, now);
    });

    test('should accept explicit updatedAt', () {
      final createdAt = DateTime(2026, 5, 19);
      final updatedAt = DateTime(2026, 5, 20);
      final review = Review(
        id: 'rev-1',
        bookId: 'book-123',
        rating: 4,
        text: 'テスト',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(review.updatedAt, updatedAt);
    });

    test('rating should be clamped to 1-5 in constructor', () {
      // 0 → 1
      final low = Review(
        id: 'r1',
        bookId: 'b1',
        rating: 0,
        text: '',
        createdAt: DateTime.now(),
      );
      expect(low.rating, 1);

      // 6 → 5
      final high = Review(
        id: 'r2',
        bookId: 'b2',
        rating: 6,
        text: '',
        createdAt: DateTime.now(),
      );
      expect(high.rating, 5);

      // 3 → 3
      final mid = Review(
        id: 'r3',
        bookId: 'b3',
        rating: 3,
        text: '',
        createdAt: DateTime.now(),
      );
      expect(mid.rating, 3);
    });

    test('== should compare by id', () {
      final now = DateTime.now();
      final r1 = Review(
        id: 'rev-1',
        bookId: 'book-a',
        rating: 5,
        text: 'Text A',
        createdAt: now,
      );
      final r2 = Review(
        id: 'rev-1',
        bookId: 'book-b',
        rating: 1,
        text: 'Text B',
        createdAt: DateTime(2020),
      );
      final r3 = Review(
        id: 'rev-2',
        bookId: 'book-a',
        rating: 5,
        text: 'Text A',
        createdAt: now,
      );

      expect(r1, equals(r2)); // same id
      expect(r1, isNot(equals(r3))); // different id
    });

    test('hashCode should be based on id', () {
      final now = DateTime.now();
      final r1 = Review(
        id: 'rev-1',
        bookId: 'book-a',
        rating: 5,
        text: 'Text A',
        createdAt: now,
      );
      final r2 = Review(
        id: 'rev-1',
        bookId: 'book-b',
        rating: 1,
        text: 'Text B',
        createdAt: DateTime(2020),
      );

      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('toString should include id and bookId', () {
      final review = Review(
        id: 'rev-1',
        bookId: 'book-123',
        rating: 4,
        text: '良い本',
        createdAt: DateTime.now(),
      );

      expect(review.toString(), contains('rev-1'));
      expect(review.toString(), contains('book-123'));
    });
  });
}
