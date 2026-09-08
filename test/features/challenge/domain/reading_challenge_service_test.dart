import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/challenge/domain/reading_challenge_service.dart';

void main() {
  // 基準日時を固定して年内/年外の判定を決定的にする
  final now = DateTime(2026, 6, 15);

  Review review({
    required String id,
    required String bookId,
    required DateTime createdAt,
  }) {
    return Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: 'text',
      createdAt: createdAt,
    );
  }

  group('ReadingChallengeService.booksReadInYear', () {
    test('該当年のレビューを持つ書籍の冊数（distinct bookId）を返す', () {
      final reviews = [
        review(id: 'r1', bookId: 'b1', createdAt: DateTime(2026, 1, 10)),
        review(id: 'r2', bookId: 'b2', createdAt: DateTime(2026, 3, 20)),
        review(id: 'r3', bookId: 'b3', createdAt: DateTime(2025, 12, 31)),
      ];
      expect(
        ReadingChallengeService.booksReadInYear(reviews, now: now),
        2,
      );
    });

    test('同一書籍の複数レビューは1冊として数える', () {
      final reviews = [
        review(id: 'r1', bookId: 'b1', createdAt: DateTime(2026, 1, 10)),
        review(id: 'r2', bookId: 'b1', createdAt: DateTime(2026, 5, 20)),
        review(id: 'r3', bookId: 'b1', createdAt: DateTime(2026, 6, 1)),
      ];
      expect(
        ReadingChallengeService.booksReadInYear(reviews, now: now),
        1,
      );
    });

    test('他年のレビューだけなら0冊を返す', () {
      final reviews = [
        review(id: 'r1', bookId: 'b1', createdAt: DateTime(2025, 1, 10)),
        review(id: 'r2', bookId: 'b2', createdAt: DateTime(2024, 3, 20)),
      ];
      expect(
        ReadingChallengeService.booksReadInYear(reviews, now: now),
        0,
      );
    });

    test('空リストなら0冊を返す', () {
      expect(ReadingChallengeService.booksReadInYear([], now: now), 0);
    });
  });

  group('ReadingChallengeService.progress', () {
    test('進捗率を計算する', () {
      expect(ReadingChallengeService.progress(3, 5), closeTo(0.6, 0.001));
    });

    test('読了が目標を超えても1.0にクランプする', () {
      expect(ReadingChallengeService.progress(10, 5), 1.0);
    });

    test('目標未設定（0以下）なら0.0を返す', () {
      expect(ReadingChallengeService.progress(3, 0), 0.0);
      expect(ReadingChallengeService.progress(3, -5), 0.0);
    });
  });

  group('ReadingChallengeService.isAchieved', () {
    test('読了が目標以上なら達成', () {
      expect(ReadingChallengeService.isAchieved(5, 5), isTrue);
      expect(ReadingChallengeService.isAchieved(6, 5), isTrue);
    });

    test('読了が目標未満なら未達成', () {
      expect(ReadingChallengeService.isAchieved(4, 5), isFalse);
    });

    test('目標未設定（0以下）では達成とみなさない', () {
      expect(ReadingChallengeService.isAchieved(10, 0), isFalse);
      expect(ReadingChallengeService.isAchieved(0, 0), isFalse);
    });
  });
}
