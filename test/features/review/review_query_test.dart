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

const _titles = <String, String>{
  'b1': 'Flutter入門',
  'b2': 'Dart言語仕様',
  'b3': '設計原則',
};

void main() {
  group('normalize', () {
    test('全角英数字・全角空白・大文字小文字を正規化する', () {
      expect(ReviewQueryService.normalize('  ＦＬＵＴＴＥＲ　１００  '), 'flutter 100');
    });

    test('連続空白を単一化し trim する', () {
      expect(ReviewQueryService.normalize('  a   b\t\tc  '), 'a b c');
    });
  });

  group('matchesText', () {
    test('①本文の一部でヒットする', () {
      final r = _review('r1', text: 'とても読みやすい本でした');
      expect(ReviewQueryService.matchesText(r, null, '読みやすい'), isTrue);
    });

    test('②書名でもヒットする', () {
      final r = _review('r1', text: '特になし');
      expect(ReviewQueryService.matchesText(r, 'Dart言語仕様', '言語仕様'), isTrue);
    });

    test('③大文字小文字・全角英数・全角空白を正規化して照合する', () {
      final r = _review('r1', text: 'Flutter 最高 です');
      expect(ReviewQueryService.matchesText(r, null, 'ＦＬＵＴＴＥＲ　最高'), isTrue);
    });

    test('④複数語は AND（片方しか含まない行は除外）', () {
      final hit = _review('r1', text: 'Flutter は 最高');
      final miss = _review('r2', text: 'Flutter だけ');
      expect(ReviewQueryService.matchesText(hit, null, 'flutter 最高'), isTrue);
      expect(ReviewQueryService.matchesText(miss, null, 'flutter 最高'), isFalse);
    });

    test('本文と書名をまたいで複数語が成立する', () {
      final r = _review('r1', text: 'とても良い');
      expect(ReviewQueryService.matchesText(r, 'Flutter入門', '最高 flutter'), isFalse);
      expect(ReviewQueryService.matchesText(r, 'Flutter入門', '良い flutter'), isTrue);
    });

    test('空・空白のみの検索語は全件ヒット', () {
      final r = _review('r1', text: 'なにか');
      expect(ReviewQueryService.matchesText(r, null, ''), isTrue);
      expect(ReviewQueryService.matchesText(r, null, '   '), isTrue);
    });

    test('⑫bookTitle が null でも本文でヒットする', () {
      final r = _review('r1', text: 'Dart の null 安全がわかる');
      expect(ReviewQueryService.matchesText(r, null, 'null 安全'), isTrue);
    });
  });

  group('apply', () {
    test('⑤該当0件なら空リスト', () {
      final reviews = [_review('r1', text: 'あ')];
      final result = ReviewQueryService.apply(
        reviews,
        _titles,
        const ReviewQuery(text: '存在しない語'),
      );
      expect(result, isEmpty);
    });

    test('⑥createdAt 降順・同日時は id 昇順で安定ソートされる', () {
      final reviews = [
        _review('r3', text: 'x', createdAt: DateTime(2026, 1, 2)),
        _review('r2', text: 'x', createdAt: DateTime(2026, 1, 3)),
        _review('r1', text: 'x', createdAt: DateTime(2026, 1, 2)),
        _review('r0', text: 'x', createdAt: DateTime(2026, 1, 3)),
      ];
      final result = ReviewQueryService.apply(
        reviews,
        _titles,
        const ReviewQuery(text: 'x'),
      );
      expect(result.map((e) => e.review.id).toList(), ['r0', 'r2', 'r1', 'r3']);
    });

    test('⑦bookId で絞り込む', () {
      final reviews = [
        _review('r1', bookId: 'b1', text: 'x'),
        _review('r2', bookId: 'b2', text: 'x'),
      ];
      final result = ReviewQueryService.apply(
        reviews,
        _titles,
        const ReviewQuery(bookId: 'b2'),
      );
      expect(result.map((e) => e.review.id).toList(), ['r2']);
    });

    test('⑧minRating で絞り込む（以上）', () {
      final reviews = [
        _review('r1', rating: 3, text: 'x'),
        _review('r2', rating: 5, text: 'x'),
      ];
      final result = ReviewQueryService.apply(
        reviews,
        _titles,
        const ReviewQuery(minRating: 4),
      );
      expect(result.map((e) => e.review.id).toList(), ['r2']);
    });

    test('⑨from/to は両端を含む', () {
      final reviews = [
        _review('r1', text: 'x', createdAt: DateTime(2026, 1, 1)),
        _review('r2', text: 'x', createdAt: DateTime(2026, 1, 5)),
        _review('r3', text: 'x', createdAt: DateTime(2026, 1, 9)),
      ];
      final result = ReviewQueryService.apply(
        reviews,
        _titles,
        ReviewQuery(
          text: 'x',
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 1, 5),
        ),
      );
      expect(result.map((e) => e.review.id).toList(), ['r2', 'r1']);
    });

    test('bookTitle を結果に含め、未知の bookId は null になる', () {
      final reviews = [
        _review('r1', bookId: 'b1', text: 'x'),
        _review('r2', bookId: 'zzz', text: 'x'),
      ];
      final result = ReviewQueryService.apply(
        reviews,
        _titles,
        const ReviewQuery(text: 'x'),
      );
      // 同日時なので id 昇順（r1 → r2）
      expect(result.map((e) => e.review.id).toList(), ['r1', 'r2']);
      expect(result.map((e) => e.bookTitle).toList(), ['Flutter入門', null]);
    });

    test('⑪入力リストを破壊しない', () {
      final reviews = [
        _review('r1', text: 'x', createdAt: DateTime(2026, 1, 1)),
        _review('r2', text: 'x', createdAt: DateTime(2026, 1, 3)),
        _review('r3', text: 'x', createdAt: DateTime(2026, 1, 2)),
      ];
      final before = reviews.map((e) => e.id).toList();
      ReviewQueryService.apply(reviews, _titles, const ReviewQuery(text: 'x'));
      expect(reviews.map((e) => e.id).toList(), before);
    });
  });

  group('excerpt', () {
    test('⑩改行・連続空白を単一空白へ畳む', () {
      expect(
        ReviewQueryService.excerpt('一行目\n\n二行目   三行目'),
        '一行目 二行目 三行目',
      );
    });

    test('⑩maxLength 超過時は末尾を省略記号にし、長さは maxLength 以内', () {
      final text = 'あ' * 100;
      final result = ReviewQueryService.excerpt(text, maxLength: 10);
      expect(result, '${'あ' * 9}…');
      expect(result.length, 10);
    });

    test('⑩超過しない場合はそのまま返す', () {
      expect(ReviewQueryService.excerpt('短い本文', maxLength: 80), '短い本文');
      expect(ReviewQueryService.excerpt('あ' * 80, maxLength: 80), 'あ' * 80);
    });

    test('⑩maxLength <= 0 は空文字', () {
      expect(ReviewQueryService.excerpt('なにか', maxLength: 0), '');
      expect(ReviewQueryService.excerpt('なにか', maxLength: -3), '');
    });
  });

  group('ReviewQuery.copyWith / ReviewSearchResult', () {
    test('copyWith は指定値のみ差し替える', () {
      const base = ReviewQuery(text: 'a', bookId: 'b1', minRating: 3);
      final next = base.copyWith(text: 'b', minRating: 5);
      expect(next.text, 'b');
      expect(next.bookId, 'b1');
      expect(next.minRating, 5);
    });

    test('copyWith の clear フラグで null に戻せる', () {
      final base = ReviewQuery(
        bookId: 'b1',
        minRating: 3,
        from: DateTime(2026, 1, 1),
      );
      final next = base.copyWith(
        clearBookId: true,
        clearMinRating: true,
        clearFrom: true,
      );
      expect(next.bookId, isNull);
      expect(next.minRating, isNull);
      expect(next.from, isNull);
    });

    test('ReviewSearchResult の同一性は review.id 基準', () {
      final a = ReviewSearchResult(review: _review('r1'), bookTitle: 'A');
      final b = ReviewSearchResult(review: _review('r1'), bookTitle: 'B');
      final c = ReviewSearchResult(review: _review('r2'), bookTitle: 'A');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
