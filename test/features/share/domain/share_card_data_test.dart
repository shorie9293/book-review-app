import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/share/domain/share_card_data.dart';

void main() {
  group('ShareCardReview', () {
    test('rating範囲外はArgumentError', () {
      expect(
        () => ShareCardReview(bookTitle: '本', rating: 0, excerpt: 'x'),
        throwsArgumentError,
      );
      expect(
        () => ShareCardReview(bookTitle: '本', rating: 6, excerpt: 'x'),
        throwsArgumentError,
      );
    });

    test('空タイトルは無題になる', () {
      expect(
        ShareCardReview(bookTitle: '', rating: 3, excerpt: 'x').bookTitle,
        '無題',
      );
      expect(
        ShareCardReview(bookTitle: '   ', rating: 3, excerpt: 'x').bookTitle,
        '無題',
      );
    });

    test('excerptはtrimされる', () {
      expect(
        ShareCardReview(bookTitle: '本', rating: 3, excerpt: '  良い  ').excerpt,
        '良い',
      );
    });
  });

  group('ShareCardData', () {
    ShareCardData build({
      int completed = 1,
      int unread = 2,
      int minutes = 3,
      int days = 4,
      ShareCardReview? favorite,
    }) {
      return ShareCardData(
        completedCount: completed,
        unreadCount: unread,
        totalMinutes: minutes,
        activeDays: days,
        favoriteReview: favorite,
        generatedAt: DateTime(2026, 1, 15),
      );
    }

    test('負値はArgumentError', () {
      expect(() => build(completed: -1), throwsArgumentError);
      expect(() => build(unread: -1), throwsArgumentError);
      expect(() => build(minutes: -1), throwsArgumentError);
      expect(() => build(days: -1), throwsArgumentError);
    });

    test('ラベルの書式', () {
      final d = build(completed: 3, unread: 5);
      expect(d.completedLabel, '読了 3冊');
      expect(d.unreadLabel, '積読 5冊');
    });

    test('minutesLabelはtotalLabelと同じ書式', () {
      expect(build(minutes: 750).minutesLabel, '12時間30分');
      expect(build(minutes: 45).minutesLabel, '45分');
      expect(build(minutes: 0).minutesLabel, '0分');
      expect(build(minutes: 120).minutesLabel, '2時間');
    });

    test('favoriteReviewはnull許容', () {
      expect(build().favoriteReview, isNull);
    });
  });
}
