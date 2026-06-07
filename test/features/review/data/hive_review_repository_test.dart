import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';
import 'dart:io';

void main() {
  late Directory tempDir;
  late HiveReviewRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
    repository = HiveReviewRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await Hive.deleteBoxFromDisk('reviews');
    tempDir.deleteSync(recursive: true);
  });

  group('HiveReviewRepository', () {
    test('addReviewしたレビューをgetReviewsByBookIdで取得できる', () async {
      final review = Review(
        id: 'review-1',
        bookId: 'book-1',
        rating: 4,
        text: 'とても面白かった',
        createdAt: DateTime(2024, 1, 15),
      );

      await repository.addReview(review);
      final reviews = await repository.getReviewsByBookId('book-1');

      expect(reviews.length, 1);
      expect(reviews.first.id, 'review-1');
      expect(reviews.first.rating, 4);
      expect(reviews.first.text, 'とても面白かった');
    });

    test('複数レビューを追加してすべて取得できる', () async {
      final review1 = Review(
        id: 'r1',
        bookId: 'book-1',
        rating: 5,
        text: 'Great!',
        createdAt: DateTime(2024, 1, 1),
      );
      final review2 = Review(
        id: 'r2',
        bookId: 'book-1',
        rating: 3,
        text: 'So so',
        createdAt: DateTime(2024, 2, 1),
      );

      await repository.addReview(review1);
      await repository.addReview(review2);
      final reviews = await repository.getReviewsByBookId('book-1');

      expect(reviews.length, 2);
    });

    test('getReviewsByBookIdで正しいbookIdのものだけフィルタリングできる', () async {
      final reviewA1 = Review(
        id: 'a1',
        bookId: 'book-a',
        rating: 5,
        text: 'A is great',
        createdAt: DateTime(2024, 1, 1),
      );
      final reviewB1 = Review(
        id: 'b1',
        bookId: 'book-b',
        rating: 2,
        text: 'B is bad',
        createdAt: DateTime(2024, 2, 1),
      );
      final reviewA2 = Review(
        id: 'a2',
        bookId: 'book-a',
        rating: 4,
        text: 'A is also good',
        createdAt: DateTime(2024, 3, 1),
      );

      await repository.addReview(reviewA1);
      await repository.addReview(reviewB1);
      await repository.addReview(reviewA2);

      final reviewsA = await repository.getReviewsByBookId('book-a');
      final reviewsB = await repository.getReviewsByBookId('book-b');

      expect(reviewsA.length, 2);
      expect(reviewsB.length, 1);
      expect(reviewsB.first.id, 'b1');
    });

    test('updateReviewで既存レビューを更新できる', () async {
      final review = Review(
        id: 'update-me',
        bookId: 'book-1',
        rating: 2,
        text: 'ひどい',
        createdAt: DateTime(2024, 1, 1),
      );

      await repository.addReview(review);

      final updatedReview = Review(
        id: 'update-me',
        bookId: 'book-1',
        rating: 4,
        text: '読み直したら良かった',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 2, 1),
      );

      await repository.updateReview(updatedReview);
      final reviews = await repository.getReviewsByBookId('book-1');

      expect(reviews.length, 1);
      expect(reviews.first.rating, 4);
      expect(reviews.first.text, '読み直したら良かった');
      expect(reviews.first.updatedAt, DateTime(2024, 2, 1));
    });

    test('deleteReviewでレビューを削除できる', () async {
      final review = Review(
        id: 'to-delete',
        bookId: 'book-1',
        rating: 3,
        text: '消えるレビュー',
        createdAt: DateTime(2024, 1, 1),
      );

      await repository.addReview(review);
      expect(await repository.getReviewsByBookId('book-1'), hasLength(1));

      await repository.deleteReview('to-delete');
      final reviews = await repository.getReviewsByBookId('book-1');

      expect(reviews, isEmpty);
    });

    test('存在しないIDのdeleteReviewはエラーにならない', () async {
      final review = Review(
        id: 'keep-me',
        bookId: 'book-1',
        rating: 5,
        text: '残るレビュー',
        createdAt: DateTime(2024, 1, 1),
      );

      await repository.addReview(review);

      // 存在しないIDを削除してもエラーにならない
      await repository.deleteReview('non-existent-id');
      expect(await repository.getReviewsByBookId('book-1'), hasLength(1));
    });

    test('レビューのないbookIdでgetReviewsByBookIdは空リストを返す', () async {
      final review = Review(
        id: 'review-1',
        bookId: 'book-with-review',
        rating: 4,
        text: 'レビューあり',
        createdAt: DateTime(2024, 1, 1),
      );

      await repository.addReview(review);

      final reviews = await repository.getReviewsByBookId('book-without-review');

      expect(reviews, isEmpty);
    });

    test('clearで全レビューをクリアできる', () async {
      final review1 = Review(
        id: 'r1',
        bookId: 'book-1',
        rating: 5,
        text: 'One',
        createdAt: DateTime(2024, 1, 1),
      );
      final review2 = Review(
        id: 'r2',
        bookId: 'book-2',
        rating: 4,
        text: 'Two',
        createdAt: DateTime(2024, 2, 1),
      );

      await repository.addReview(review1);
      await repository.addReview(review2);
      expect(await repository.getReviewsByBookId('book-1'), hasLength(1));
      expect(await repository.getReviewsByBookId('book-2'), hasLength(1));

      await repository.clear();

      expect(await repository.getReviewsByBookId('book-1'), isEmpty);
      expect(await repository.getReviewsByBookId('book-2'), isEmpty);
    });
  });
}
