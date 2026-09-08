import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'dart:io';

void main() {
  late Directory tempDir;
  late HiveChallengeRepository repository;
  late HiveReviewRepository reviewRepository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_challenge_test_');
    Hive.init(tempDir.path);
    reviewRepository = HiveReviewRepository();
    await reviewRepository.init();
    repository = HiveChallengeRepository();
    await repository.init();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('challenge');
    await Hive.deleteBoxFromDisk('reviews');
    tempDir.deleteSync(recursive: true);
  });

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

  group('HiveChallengeRepository', () {
    test('未設定の年間目標は0を返す', () async {
      expect(await repository.getAnnualTarget(), 0);
    });

    test('年間目標を設定すると読み出せる', () async {
      await repository.setAnnualTarget(12);
      expect(await repository.getAnnualTarget(), 12);
    });

    test('年間目標の負値は0として保存される', () async {
      await repository.setAnnualTarget(-3);
      expect(await repository.getAnnualTarget(), 0);
    });

    test('getAllReviewsで reviews ボックスの全レビューを取得できる', () async {
      await reviewRepository.addReview(
        review(id: 'r1', bookId: 'b1', createdAt: DateTime(2026, 1, 10)),
      );
      await reviewRepository.addReview(
        review(id: 'r2', bookId: 'b2', createdAt: DateTime(2026, 3, 20)),
      );
      await reviewRepository.addReview(
        review(id: 'r3', bookId: 'b3', createdAt: DateTime(2025, 12, 31)),
      );

      final reviews = await repository.getAllReviews();
      final ids = reviews.map((r) => r.id).toSet();
      expect(ids, {'r1', 'r2', 'r3'});
    });

    test('レビューが無ければ空リストを返す', () async {
      expect(await repository.getAllReviews(), isEmpty);
    });
  });
}
