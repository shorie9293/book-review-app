import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:book_review_app/core/time/local_calendar_date.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/challenge/domain/reading_challenge_service.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';
import 'package:book_review_app/features/review/domain/review_query.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_card.dart';

/// 親探針（十一月十四日・#246）。
///
/// 子の試練は「個別関数がローカル暦を返すこと」を撃つ。
/// ここでは **層を貫く合成**（保存 → 復元 → 判定／表示）と
/// **意味不変**（瞬間が動かないこと）を独立に固定する。
/// 期待値は必ず `toLocal()` から算出し、JST 決め打ちを書かない。
void main() {
  group('親探針: 復元境界で UTC 種別を下流へ流さない', () {
    late Directory tempDir;
    late HiveReviewRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_parent_probe_');
      Hive.init(tempDir.path);
      repository = HiveReviewRepository();
      await repository.init(boxName: 'reviews_probe');
    });

    tearDown(() async {
      await repository.clear();
      await Hive.deleteBoxFromDisk('reviews_probe');
      tempDir.deleteSync(recursive: true);
    });

    test('P1 保存→復元で種別はローカル・瞬間は不変', () async {
      // JST 00:05 / UTC 15:05（前日）。暦直読みが最も狂う境界。
      final instant = DateTime.parse('2026-10-31T15:05:00.000Z');
      expect(instant.isUtc, isTrue, reason: '前提: 入力は UTC 種別');

      await repository.addReview(Review(
        id: 'p1',
        bookId: 'b1',
        rating: 5,
        text: '境界',
        createdAt: instant,
      ));

      final restored = (await repository.getReviewsByBookId('b1')).single;

      // 不変条件1: 復元後はローカル種別（UTC 種別を下流へ流さない）
      expect(restored.createdAt.isUtc, isFalse);
      // 不変条件2: 瞬間は動かない（保存形式の意味論を壊さない）
      expect(restored.createdAt.isAtSameMomentAs(instant), isTrue);
      // 不変条件3: 暦はローカル暦で読める
      final local = instant.toLocal();
      expect(localYear(restored.createdAt), local.year);
      expect(localMonth(restored.createdAt), local.month);
      expect(localDay(restored.createdAt), local.day);
    });

    test('P2 年間チャレンジの年判定はローカル暦（UTC の .year 直読みを検出）', () {
      // JST 2027-01-01 01:00 / UTC 2026-12-31 16:00
      final instant = DateTime.parse('2026-12-31T16:00:00.000Z');
      final now = DateTime.parse('2027-06-01T00:00:00.000Z');
      final reviews = [
        Review(
            id: 'p2', bookId: 'b-p2', rating: 4, text: '年跨ぎ', createdAt: instant),
      ];

      // 期待値は toLocal() から算出（TZ 非依存の書き方）
      final expected = instant.toLocal().year == now.toLocal().year ? 1 : 0;
      final actual =
          ReadingChallengeService.booksReadInYear(reviews, now: now);

      expect(actual, expected);
    });

    test('P3 表示用の暦読みはローカル暦（UTC 直読みとの識別）', () {
      final instant = DateTime.parse('2026-10-31T15:05:00.000Z');
      final local = instant.toLocal();

      expect(formatLocalDate(instant),
          '${local.year}/${local.month}/${local.day}');
      expect(localDateOnly(instant).isUtc, isFalse);
      expect(localYear(instant), local.year);
    });

    test('P4 BookNote 復元も同契約（種別ローカル・瞬間不変）', () {
      const raw = '2026-10-31T15:05:00.000Z';
      final note = BookNote.fromJson({
        'id': 'n1',
        'bookId': 'b1',
        'content': '本文',
        'createdAt': raw,
      });

      expect(note.createdAt.isUtc, isFalse);
      expect(note.createdAt.isAtSameMomentAs(DateTime.parse(raw)), isTrue);
      // updatedAt 欠落時は createdAt を引き継ぐ既存仕様は不変
      expect(note.updatedAt.isAtSameMomentAs(note.createdAt), isTrue);
    });

    test('P5 期間絞込は瞬間比較のまま（正規化で集合が変わらない）', () {
      final a = Review(
        id: 'a',
        bookId: 'b1',
        rating: 4,
        text: 'あ',
        createdAt: DateTime.parse('2026-10-31T15:05:00.000Z'),
      );
      final b = Review(
        id: 'b',
        bookId: 'b1',
        rating: 4,
        text: 'い',
        createdAt: DateTime.parse('2026-11-02T00:00:00.000Z'),
      );

      final from = DateTime.parse('2026-11-01T00:00:00.000Z');
      final to = DateTime.parse('2026-11-30T23:59:59.000Z');

      final result = ReviewQueryService.apply(
        [a, b],
        {'b1': '本'},
        ReviewQuery(from: from, to: to),
      );

      // 瞬間で判定: a は範囲外、b は範囲内（暦の見え方に依存しない）
      expect(result.map((r) => r.review.id).toList(), ['b']);
    });
  });

  testWidgets('P6 ReviewCard は Z 付き createdAt でもローカル暦を描く', (tester) async {
    final instant = DateTime.parse('2026-10-31T15:05:00.000Z');
    final local = instant.toLocal();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReviewCard(
          review: Review(
            id: 'p6',
            bookId: 'b1',
            rating: 5,
            text: 'カード',
            createdAt: instant,
          ),
          onDelete: () {},
          onEdit: () {},
        ),
      ),
    ));

    final dateText = tester.widget<Text>(
      find.byKey(const Key('review_card_date')),
    );
    expect(dateText.data, '${local.year}/${local.month}/${local.day}');
  });
}
