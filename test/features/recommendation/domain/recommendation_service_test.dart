import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/recommendation/domain/book_recommendation.dart';
import 'package:book_review_app/features/recommendation/domain/recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book({
  required String id,
  required String title,
  String? author,
  List<String> genres = const [],
  ReadingStatus status = ReadingStatus.unread,
}) {
  return Book(
    id: id,
    title: title,
    author: author ?? '著者$id',
    isbn: 'isbn-$id',
    genres: genres,
    readingStatus: status,
  );
}

Review _review({
  required String id,
  required String bookId,
  required int rating,
}) {
  final now = DateTime(2026);
  return Review(
    id: id,
    bookId: bookId,
    rating: rating,
    text: '',
    createdAt: now,
  );
}

void main() {
  group('空入力・limit', () {
    test('books空 → 空リスト', () {
      expect(
        RecommendationService.recommend(books: const [], reviews: const []),
        isEmpty,
      );
    });

    test('limit=0 → 空リスト', () {
      final books = [_book(id: 'b1', title: 'A')];
      expect(
        RecommendationService.recommend(
            books: books, reviews: const [], limit: 0),
        isEmpty,
      );
    });

    test('limit負 → 空リスト', () {
      final books = [_book(id: 'b1', title: 'A')];
      expect(
        RecommendationService.recommend(
            books: books, reviews: const [], limit: -3),
        isEmpty,
      );
    });

    test('limit>件数 → 全候補を返す', () {
      final books = [_book(id: 'b1', title: 'A'), _book(id: 'b2', title: 'B')];
      final r = RecommendationService.recommend(
          books: books, reviews: const [], limit: 10);
      expect(r.length, 2);
    });

    test('defaultLimitは5', () {
      expect(RecommendationService.defaultLimit, 5);
    });
  });

  group('読了除外', () {
    test('読了本のみ → 空リスト（境界）', () {
      final books = [_book(id: 'b1', title: 'A', status: ReadingStatus.finished)];
      expect(
        RecommendationService.recommend(books: books, reviews: const []),
        isEmpty,
      );
    });

    test('読了は候補外・積読と読書中は候補', () {
      final books = [
        _book(id: 'fin', title: 'F', status: ReadingStatus.finished),
        _book(id: 'unread', title: 'U'),
        _book(id: 'reading', title: 'R', status: ReadingStatus.reading),
      ];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.map((x) => x.bookId).toSet(), {'unread', 'reading'});
    });
  });

  group('嗜好プロファイル', () {
    test('読了本のジャンルが嗜好になる', () {
      final books = [
        _book(id: 'fin', title: 'F', genres: ['SF'],
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', genres: ['SF']),
      ];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.single.bookId, 'c1');
      expect(r.single.score, 3);
      expect(r.single.matchedGenres, ['SF']);
    });

    test('rating>=4のレビュー本のジャンルが嗜好になる', () {
      final books = [
        _book(id: 'src', title: 'S', genres: ['歴史']),
        _book(id: 'c1', title: 'C', genres: ['歴史']),
      ];
      final r = RecommendationService.recommend(
        books: books,
        reviews: [_review(id: 'r1', bookId: 'src', rating: 5)],
      ).where((x) => x.bookId == 'c1').toList();
      expect(r.single.matchedGenres, ['歴史']);
      expect(r.single.score, 3);
    });

    test('rating3のレビューは嗜好にならない', () {
      final books = [
        _book(id: 'src', title: 'S', genres: ['歴史']),
        _book(id: 'c1', title: 'C', genres: ['歴史']),
      ];
      final r = RecommendationService.recommend(
        books: books,
        reviews: [_review(id: 'r1', bookId: 'src', rating: 3)],
      ).where((x) => x.bookId == 'c1').toList();
      expect(r.single.matchedGenres, isEmpty);
      expect(r.single.score, 0);
    });

    test('未知bookIdのレビューは無視', () {
      final books = [_book(id: 'c1', title: 'C')];
      final r = RecommendationService.recommend(
        books: books,
        reviews: [_review(id: 'r1', bookId: 'unknown', rating: 5)],
      );
      expect(r.single.score, 0);
      expect(r.single.reason, '積読を消化しましょう');
    });

    test('読書中の本(rating>=4)も嗜好源になる', () {
      final books = [
        _book(id: 'src', title: 'S', genres: ['ミステリー'],
            status: ReadingStatus.reading),
        _book(id: 'c1', title: 'C', genres: ['ミステリー']),
      ];
      final r = RecommendationService.recommend(
        books: books,
        reviews: [_review(id: 'r1', bookId: 'src', rating: 4)],
      ).where((x) => x.bookId == 'c1').toList();
      expect(r.single.matchedGenres, ['ミステリー']);
    });
  });

  group('スコア', () {
    test('ジャンル一致は1件×3点', () {
      final books = [
        _book(id: 'fin', title: 'F', genres: ['SF'],
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', genres: ['SF']),
      ];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .score,
        3,
      );
    });

    test('ジャンル2件一致は6点', () {
      final books = [
        _book(id: 'fin', title: 'F', genres: ['SF', '歴史'],
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', genres: ['SF', '歴史']),
      ];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .score,
        6,
      );
    });

    test('著者一致は+5', () {
      final books = [
        _book(id: 'fin', title: 'F', author: '夏目',
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', author: '夏目'),
      ];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .score,
        5,
      );
    });

    test('読書中候補は+2', () {
      final books = [
        _book(id: 'c1', title: 'C', status: ReadingStatus.reading),
      ];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .score,
        2,
      );
    });

    test('著者+ジャンル+読書中の複合 = 3+5+2=10', () {
      final books = [
        _book(id: 'fin', title: 'F', author: '夏目', genres: ['SF'],
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', author: '夏目', genres: ['SF'],
            status: ReadingStatus.reading),
      ];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .score,
        10,
      );
    });
  });

  group('並び順', () {
    test('score降順で並ぶ', () {
      final books = [
        _book(id: 'fin', title: 'F', author: 'X', genres: ['SF'],
            status: ReadingStatus.finished),
        _book(id: 'low', title: 'Low'),
        _book(id: 'mid', title: 'Mid', genres: ['SF']),
        _book(id: 'high', title: 'High', author: 'X', genres: ['SF']),
      ];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.map((x) => x.bookId).toList(), ['high', 'mid', 'low']);
    });

    test('同scoreはtitle昇順（安定）', () {
      final books = [
        _book(id: 'b2', title: 'ば'),
        _book(id: 'b1', title: 'あ'),
        _book(id: 'b3', title: 'い'),
      ];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.map((x) => x.title).toList(), ['あ', 'い', 'ば']);
    });

    test('同score同titleはid昇順', () {
      final books = [
        _book(id: 'b2', title: '同'),
        _book(id: 'b1', title: '同'),
      ];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.map((x) => x.bookId).toList(), ['b1', 'b2']);
    });

    test('limitで先頭N件に切り詰める', () {
      final books = List.generate(7, (i) => _book(id: 'b$i', title: 't$i'));
      final r = RecommendationService.recommend(
          books: books, reviews: const [], limit: 3);
      expect(r.length, 3);
      expect(r.map((x) => x.bookId).toList(), ['b0', 'b1', 'b2']);
    });

    test('元のbooksリストを変更しない（非破壊）', () {
      final books = [
        _book(id: 'b2', title: 'ば'),
        _book(id: 'b1', title: 'あ'),
      ];
      final before = books.map((b) => b.id).toList();
      RecommendationService.recommend(books: books, reviews: const []);
      expect(books.map((b) => b.id).toList(), before);
    });
  });

  group('matchedGenres', () {
    test('昇順・重複除去される', () {
      final books = [
        _book(id: 'fin', title: 'F',
            genres: ['SF', '歴史', 'SF'], status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', genres: ['歴史', 'SF', '歴史']),
      ];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.single.matchedGenres, ['SF', '歴史']);
    });

    test('一致無しはconst []', () {
      final books = [_book(id: 'c1', title: 'C')];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.single.matchedGenres, isEmpty);
      expect(identical(r.single.matchedGenres, const <String>[]), isTrue);
    });

    test('ジャンル比較は前後空白をtrim', () {
      final books = [
        _book(id: 'fin', title: 'F', genres: ['SF '],
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', genres: [' SF']),
      ];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.single.matchedGenres, ['SF']);
    });
  });

  group('reason 4パターン', () {
    test('著者+ジャンル一致', () {
      final books = [
        _book(id: 'fin', title: 'F', author: '夏目', genres: ['SF'],
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', author: '夏目', genres: ['SF']),
      ];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .reason,
        '好きな著者「夏目」・ジャンル「SF」',
      );
    });

    test('著者一致のみ', () {
      final books = [
        _book(id: 'fin', title: 'F', author: '夏目',
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', author: '夏目'),
      ];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .reason,
        '好きな著者「夏目」',
      );
    });

    test('ジャンル一致のみ', () {
      final books = [
        _book(id: 'fin', title: 'F', genres: ['SF'],
            status: ReadingStatus.finished),
        _book(id: 'c1', title: 'C', genres: ['SF']),
      ];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .reason,
        '好きなジャンル「SF」',
      );
    });

    test('いずれも無し', () {
      final books = [_book(id: 'c1', title: 'C')];
      expect(
        RecommendationService.recommend(books: books, reviews: const [])
            .single
            .reason,
        '積読を消化しましょう',
      );
    });
  });

  group('値オブジェクト', () {
    test('== はbookId基準 / hashCode一致', () {
      final a = const BookRecommendation(
          bookId: 'x', title: 'A', author: 'B', score: 1, reason: 'r');
      final b = const BookRecommendation(
          bookId: 'x', title: 'Z', author: 'Y', score: 9, reason: 'q');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == Object(), isFalse);
    });

    test('reviews空でも動く', () {
      final books = [_book(id: 'c1', title: 'C')];
      final r = RecommendationService.recommend(books: books, reviews: const []);
      expect(r.single.bookId, 'c1');
    });
  });
}
