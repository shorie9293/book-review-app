import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/review/domain/review_query.dart';
import 'package:flutter_test/flutter_test.dart';

Review _review(
  String id, {
  String bookId = 'b1',
  int rating = 3,
  String text = '',
  DateTime? createdAt,
}) {
  final at = createdAt ?? DateTime(2026, 1, 1);
  return Review(
    id: id,
    bookId: bookId,
    rating: rating,
    text: text,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  group('レビュー横断検索のかな表記ゆれ吸収', () {
    test('本文のカタカナ語がひらがなクエリでヒットする', () {
      final r = _review('r1', text: 'ガッコウの図書館で借りた');
      expect(ReviewQueryService.matchesText(r, null, 'がっこう'), isTrue);
      expect(ReviewQueryService.matchesText(r, null, 'ｶﾞｯｺｳ'), isTrue);
    });

    test('書名のカタカナがひらがなクエリでヒットする', () {
      final r = _review('r1', text: '特になし');
      expect(ReviewQueryService.matchesText(r, 'ヨミカタ練習帳', 'よみかた'), isTrue);
    });

    test('半角カナ＋濁点の本文が全角カナクエリでヒットする', () {
      final r = _review('r1', text: 'ｶﾞｯｺｳの帰りに読んだ');
      expect(ReviewQueryService.matchesText(r, null, 'ガッコウ'), isTrue);
    });

    test('複数語 AND の意味論は不変（片方しか含まない行は除外）', () {
      final hit = _review('r1', text: 'ガッコウは たのしい');
      final miss = _review('r2', text: 'ガッコウだけ');
      expect(ReviewQueryService.matchesText(hit, null, 'がっこう たのしい'), isTrue);
      expect(ReviewQueryService.matchesText(miss, null, 'がっこう たのしい'), isFalse);
    });

    test('本文と書名をまたぐ複数語も従来どおり成立する', () {
      final r = _review('r1', text: 'よみやすい');
      expect(ReviewQueryService.matchesText(r, 'ヨミカタ入門', 'ヨミカタ よみやすい'),
          isTrue);
    });

    test('既存 normalize の戻り値は不変（かな畳み込みしない）', () {
      expect(ReviewQueryService.normalize('よみかた'), 'よみかた');
      expect(ReviewQueryService.normalize('ｶﾞｯｺｳ'), 'ｶﾞｯｺｳ');
    });

    test('normalizeForSearch はかなを畳む', () {
      expect(ReviewQueryService.normalizeForSearch('よみかた'), 'ヨミカタ');
      expect(
        ReviewQueryService.normalizeForSearch('ｶﾞｯｺｳ'),
        ReviewQueryService.normalizeForSearch('がっこう'),
      );
    });

    test('apply の並び（createdAt 降順・同時刻は id 昇順）は不変', () {
      final reviews = [
        _review('r1', text: 'ガッコウ', createdAt: DateTime(2026, 1, 1)),
        _review('r2', text: 'がっこう', createdAt: DateTime(2026, 1, 3)),
        _review('r3', text: 'ｶﾞｯｺｳ', createdAt: DateTime(2026, 1, 3)),
        _review('r4', text: '無関係', createdAt: DateTime(2026, 1, 2)),
      ];
      final result = ReviewQueryService.apply(
        reviews,
        const <String, String>{},
        const ReviewQuery(text: 'がっこう'),
      );
      expect(result.map((e) => e.review.id).toList(), ['r2', 'r3', 'r1']);
    });
  });
}
