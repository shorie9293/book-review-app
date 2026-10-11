import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/reading/domain/reading_stats.dart';
import 'package:book_review_app/features/share/domain/share_card_service.dart';

Book book(String id, ReadingStatus status, {String? title}) =>
    Book(id: id, title: title ?? '本$id', author: 'a', isbn: 'i', readingStatus: status);

Review review(
  String id,
  String bookId,
  int rating,
  String text,
  DateTime createdAt,
) =>
    Review(id: id, bookId: bookId, rating: rating, text: text, createdAt: createdAt);

const stats = ReadingStats(
  totalMinutes: 750,
  sessionCount: 3,
  bookCount: 2,
  activeDays: 4,
);

void main() {
  group('normalizeExcerpt', () {
    test('連続空白・改行・タブを圧縮してtrim', () {
      expect(
        ShareCardService.normalizeExcerpt('  a\n\nb\t\tc  d  ', 100),
        'a b c d',
      );
    });

    test('maxLen超過は切り詰めて…', () {
      expect(
        ShareCardService.normalizeExcerpt('あ' * 45, 40),
        'あ' * 40 + '…',
      );
    });

    test('maxLenちょうどは…なし', () {
      expect(
        ShareCardService.normalizeExcerpt('あ' * 40, 40),
        'あ' * 40,
      );
    });

    test('maxLen<=0はArgumentError', () {
      expect(() => ShareCardService.normalizeExcerpt('a', 0),
          throwsArgumentError);
      expect(() => ShareCardService.normalizeExcerpt('a', -1),
          throwsArgumentError);
    });
  });

  group('build', () {
    test('空booksは0', () {
      final d = ShareCardService.build(
        books: const [],
        reviews: const [],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(d.completedCount, 0);
      expect(d.unreadCount, 0);
    });

    test('読了と積読をカウント', () {
      final d = ShareCardService.build(
        books: [
          book('b1', ReadingStatus.finished),
          book('b2', ReadingStatus.finished),
          book('b3', ReadingStatus.unread),
          book('b4', ReadingStatus.reading),
        ],
        reviews: const [],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(d.completedCount, 2);
      expect(d.unreadCount, 1);
    });

    test('statsとgeneratedAtが引き継がれる', () {
      final now = DateTime(2026, 1, 15);
      final d = ShareCardService.build(
        books: const [],
        reviews: const [],
        stats: stats,
        now: now,
      );
      expect(d.totalMinutes, 750);
      expect(d.activeDays, 4);
      expect(d.generatedAt, now);
    });

    test('favorite選択: 空textは除外', () {
      final d = ShareCardService.build(
        books: [book('b1', ReadingStatus.finished, title: '本1')],
        reviews: [
          review('r1', 'b1', 5, '   ', DateTime(2026, 1, 1)),
        ],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(d.favoriteReview, isNull);
    });

    test('favorite選択: 同ratingなら新しい方', () {
      final d = ShareCardService.build(
        books: [book('b1', ReadingStatus.finished, title: '本1')],
        reviews: [
          review('r1', 'b1', 5, '古い', DateTime(2026, 1, 1)),
          review('r2', 'b1', 5, '新しい', DateTime(2026, 1, 2)),
        ],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(d.favoriteReview!.excerpt, '新しい');
    });

    test('favorite選択: 同時刻ならid昇順', () {
      final t = DateTime(2026, 1, 1);
      final d = ShareCardService.build(
        books: [book('b1', ReadingStatus.finished, title: '本1')],
        reviews: [
          review('r2', 'b1', 4, '後', t),
          review('r1', 'b1', 4, '先', t),
        ],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(d.favoriteReview!.excerpt, '先');
    });

    test('favorite選択: rating降順が最優先', () {
      final t = DateTime(2026, 1, 1);
      final d = ShareCardService.build(
        books: [book('b1', ReadingStatus.finished, title: '本1')],
        reviews: [
          review('r1', 'b1', 3, '低評価だが新しい', DateTime(2026, 1, 9)),
          review('r2', 'b1', 5, '高評価だが古い', t),
        ],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(d.favoriteReview!.excerpt, '高評価だが古い');
    });

    test('favorite: bookTitleはbookId対応・未知は無題・excerptは40字圧縮', () {
      final longText = 'a b c\n' * 10; // 60字
      final d = ShareCardService.build(
        books: [book('b1', ReadingStatus.finished, title: '本1')],
        reviews: [
          review('r1', 'unknown', 5, longText, DateTime(2026, 1, 1)),
          review('r2', 'b1', 4, 'いいね', DateTime(2026, 1, 2)),
        ],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(d.favoriteReview!.bookTitle, '無題');
      expect(
        d.favoriteReview!.excerpt,
        ShareCardService.normalizeExcerpt(longText, 40),
      );
    });

    test('全レビューが空textならfavoriteはnull', () {
      final d = ShareCardService.build(
        books: const [],
        reviews: [
          review('r1', 'b1', 5, ' ', DateTime(2026, 1, 1)),
        ],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(d.favoriteReview, isNull);
    });
  });

  group('shareText', () {
    test('favoriteなしの全行', () {
      final d = ShareCardService.build(
        books: const [],
        reviews: const [],
        stats: const ReadingStats(
          totalMinutes: 750,
          sessionCount: 1,
          bookCount: 1,
          activeDays: 2,
        ),
        now: DateTime(2026, 1, 15),
      );
      expect(
        ShareCardService.shareText(d),
        '📚 読書の歩み\n'
            '読了 0冊\n'
            '読書時間: 12時間30分\n'
            '積読 0冊\n'
            '2026/01/15',
      );
    });

    test('favoriteありは5行目が差し込まれる', () {
      final d = ShareCardService.build(
        books: [book('b1', ReadingStatus.finished, title: '吾輩は猫である')],
        reviews: [
          review('r1', 'b1', 5, '面白かった\n本当に！', DateTime(2026, 1, 1)),
        ],
        stats: stats,
        now: DateTime(2026, 1, 15),
      );
      expect(
        ShareCardService.shareText(d),
        '📚 読書の歩み\n'
            '読了 1冊\n'
            '読書時間: 12時間30分\n'
            '積読 0冊\n'
            '⭐5 「面白かった 本当に！」〈吾輩は猫である〉\n'
            '2026/01/15',
      );
    });
  });
}
