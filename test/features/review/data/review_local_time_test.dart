import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/time/local_calendar_date.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:book_review_app/features/challenge/domain/reading_challenge_service.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';
import 'package:book_review_app/features/stats/domain/reading_stats_service.dart';
import 'package:book_review_app/features/stats/domain/reading_trend.dart';

/// JST の 2026-01-01 00:05 に相当する瞬間（UTC では 2025-12-31 15:05）。
const String _zEarlyMorning = '2025-12-31T15:05:00.000Z';

void main() {
  late Directory tempDir;
  late HiveReviewRepository reviewRepository;
  late HiveChallengeRepository challengeRepository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_local_time_test_');
    Hive.init(tempDir.path);
    reviewRepository = HiveReviewRepository();
    challengeRepository = HiveChallengeRepository();
    await reviewRepository.init();
    await challengeRepository.init(boxName: 'challenge_local_time_test');
  });

  tearDown(() async {
    await reviewRepository.clear();
    await Hive.deleteBoxFromDisk('reviews');
    await Hive.deleteBoxFromDisk('challenge_local_time_test');
    tempDir.deleteSync(recursive: true);
  });

  group('HiveReviewRepository 復元境界', () {
    test('UTC 種別で保存したレビューは復元後ローカル種別になる', () async {
      final utc = DateTime.utc(2026, 1, 1, 0, 5);
      await reviewRepository.addReview(Review(
        id: 'z-1',
        bookId: 'book-1',
        rating: 4,
        text: 'Z 保存',
        createdAt: utc,
      ));

      final loaded = (await reviewRepository.getReviewsByBookId('book-1')).single;

      expect(loaded.createdAt.isUtc, isFalse);
      expect(loaded.createdAt.isAtSameMomentAs(utc), isTrue);
      expect(loaded.updatedAt.isUtc, isFalse);
    });

    test('Z 付き JSON が既にボックスにあっても復元後 isUtc == false', () async {
      final box = Hive.box<String>('reviews');
      await box.put(
        'z-raw',
        json.encode({
          'id': 'z-raw',
          'bookId': 'book-raw',
          'rating': 5,
          'text': '生 JSON',
          'createdAt': _zEarlyMorning,
          'updatedAt': _zEarlyMorning,
        }),
      );

      final loaded =
          (await reviewRepository.getReviewsByBookId('book-raw')).single;

      expect(loaded.createdAt.isUtc, isFalse);
      expect(loaded.createdAt, DateTime.parse(_zEarlyMorning).toLocal());
    });
  });

  group('HiveChallengeRepository 復元境界', () {
    test('共有 reviews ボックスの Z 付き createdAt もローカル種別へ正規化', () async {
      final box = Hive.box<String>('reviews');
      await box.put(
        'z-challenge',
        json.encode({
          'id': 'z-challenge',
          'bookId': 'book-c',
          'rating': 3,
          'text': 'チャレンジ経由',
          'createdAt': _zEarlyMorning,
          'updatedAt': _zEarlyMorning,
        }),
      );

      final loaded = (await challengeRepository.getAllReviews()).single;

      expect(loaded.createdAt.isUtc, isFalse);
      expect(loaded.createdAt, DateTime.parse(_zEarlyMorning).toLocal());
    });
  });

  group('年比較サービスが JST 早朝の Z 付き createdAt を前年へ落とさない', () {
    // 期待値は決め打ちせず、必ず parse 結果のローカル表現から算出する。
    final zParsed = DateTime.parse(_zEarlyMorning);
    final expectedYear = zParsed.toLocal().year;
    final expectedMonth = zParsed.toLocal().month;

    final utcKindReview = Review(
      id: 'year-guard',
      bookId: 'book-year',
      rating: 4,
      text: '年跨ぎ',
      createdAt: zParsed, // UTC 種別のまま渡す（サービス側の防御を撃つ）
    );
    final finishedBook = Book(
      id: 'book-year',
      title: '年跨ぎの書',
      author: '著者',
      isbn: '9784000000000',
      readingStatus: ReadingStatus.finished,
      genres: const ['小説'],
    );
    final now = DateTime(expectedYear, 12, 31, 23, 0);

    test('reading_challenge: 対象年に数える', () {
      final read = ReadingChallengeService.booksReadInYear(
        [utcKindReview],
        now: now,
      );

      expect(read, 1);
    });

    test('reading_stats: 平均評価と読了冊数に載る', () {
      final stats = ReadingStatsService.compute(
        books: [finishedBook],
        reviews: [utcKindReview],
        now: now,
      );

      expect(stats.year, expectedYear);
      expect(stats.averageRating, 4.0);
      expect(stats.totalFinished, 1);
      expect(stats.monthlyCounts[expectedMonth - 1], 1);
    });

    test('reading_trend: 対象年に数える', () {
      final trend = const ReadingTrendService().compute(
        books: [finishedBook],
        reviews: [utcKindReview],
        sessions: const [],
        now: now,
      );

      expect(trend.year, expectedYear);
      expect(trend.monthlyFinished.fold<int>(0, (a, b) => a + b), 1);
      expect(trend.monthlyFinished[expectedMonth - 1], 1);
    });

    test('正準関数で正規化した瞬間は同じ年を指す', () {
      expect(localYear(utcKindReview.createdAt), expectedYear);
      expect(normalizeToLocal(utcKindReview.createdAt).isUtc, isFalse);
    });
  });
}
