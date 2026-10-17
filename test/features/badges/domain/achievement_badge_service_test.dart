import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/badges/domain/achievement_badge.dart';
import 'package:book_review_app/features/badges/domain/achievement_badge_service.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingSession session(String id, DateTime startedAt, int minutes) =>
    ReadingSession(id: id, startedAt: startedAt, durationMinutes: minutes);

Book book(
  String id, {
  ReadingStatus status = ReadingStatus.finished,
  List<String> genres = const [],
}) =>
    Book(id: id, title: 'b$id', author: 'a', isbn: 'i$id', genres: genres, readingStatus: status);

Review review(String id) => Review(
      id: id,
      bookId: 'b',
      rating: 3,
      text: 'x',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  const service = AchievementBadgeService();
  final now = DateTime(2026, 10, 17, 12); // ローカル: 2026-10-17 (土)

  group('build: 読了冊数', () {
    test('finished のみカウントする', () {
      final c = service.build(
        books: [
          book('1', status: ReadingStatus.finished),
          book('2', status: ReadingStatus.reading),
          book('3', status: ReadingStatus.finished),
        ],
        reviews: const [],
        sessions: const [],
        now: () => now,
      );
      expect(c.progress('finished_1')!.current, 2);
    });

    test('current は required を超える生値', () {
      final books = List.generate(7, (i) => book('b$i'));
      final c = service.build(books: books, reviews: const [], sessions: const [], now: () => now);
      expect(c.progress('finished_1')!.current, 7);
      expect(c.progress('finished_1')!.ratio, 1.0);
    });
  });

  group('build: 連続読書日数', () {
    test('今日 + 昨日の連続', () {
      final c = service.build(
        books: const [],
        reviews: const [],
        sessions: [
          session('s1', DateTime(2026, 10, 17, 9), 30),
          session('s2', DateTime(2026, 10, 16, 9), 30),
          session('s3', DateTime(2026, 10, 16, 20), 30),
        ],
        now: () => now,
      );
      expect(c.progress('streak_3')!.current, 2);
    });

    test('今日セッションが無くても昨日まで連続なら連続数を保つ', () {
      final c = service.build(
        books: const [],
        reviews: const [],
        sessions: [
          session('s1', DateTime(2026, 10, 16, 9), 30),
          session('s2', DateTime(2026, 10, 15, 9), 30),
        ],
        now: () => now,
      );
      expect(c.progress('streak_3')!.current, 2);
    });

    test('日付が飛んだら 0', () {
      final c = service.build(
        books: const [],
        reviews: const [],
        sessions: [
          session('s1', DateTime(2026, 10, 15, 9), 30),
          session('s2', DateTime(2026, 10, 14, 9), 30),
        ],
        now: () => now,
      );
      expect(c.progress('streak_3')!.current, 0);
    });

    test('toLocal() で日付を判定する（UTC深夜をJSTに丸める）', () {
      // 2026-10-16T16:30Z = 2026-10-17 01:30 JST → 17日のセッション扱い
      final c = service.build(
        books: const [],
        reviews: const [],
        sessions: [session('s1', DateTime.utc(2026, 10, 16, 16, 30), 30)],
        now: () => now,
      );
      expect(c.progress('streak_3')!.current, 1);
    });

    test('空セッションなら 0', () {
      final c = service.build(books: const [], reviews: const [], sessions: const [], now: () => now);
      expect(c.progress('streak_3')!.current, 0);
    });

    test('同じ日の複数セッションは1日として数える', () {
      final c = service.build(
        books: const [],
        reviews: const [],
        sessions: [
          session('s1', DateTime(2026, 10, 17, 8), 10),
          session('s2', DateTime(2026, 10, 17, 23), 10),
        ],
        now: () => now,
      );
      expect(c.progress('streak_3')!.current, 1);
    });
  });

  group('build: ジャンル制覇', () {
    test('読了済みのジャンルを正規化して一意化', () {
      final c = service.build(
        books: [
          book('1', genres: [' SF ', 'ＳＦ', 'sf']),
          book('2', status: ReadingStatus.reading, genres: ['ミステリー']),
          book('3', genres: ['歴史', 'SF']),
        ],
        reviews: const [],
        sessions: const [],
        now: () => now,
      );
      // 正規化は空白のみ（'SF', 'ＳＦ', 'sf' は別ジャンル、'歴史' を加え4種）
      expect(c.progress('genre_5')!.current, 4);
    });

    test('連続空白は圧縮される', () {
      final c = service.build(
        books: [book('1', genres: ['空　想  科学'])],
        reviews: const [],
        sessions: const [],
        now: () => now,
      );
      expect(c.progress('genre_5')!.current, 1);
    });
  });

  group('build: レビュー・読書時間', () {
    test('レビュー投稿数', () {
      final c = service.build(
        books: const [],
        reviews: [review('r1'), review('r2')],
        sessions: const [],
        now: () => now,
      );
      expect(c.progress('review_1')!.current, 2);
    });

    test('読書時間は合計分', () {
      final c = service.build(
        books: const [],
        reviews: const [],
        sessions: [session('s1', now, 600), session('s2', now, 300)],
        now: () => now,
      );
      expect(c.progress('time_600')!.current, 900);
    });
  });

  group('build: その他', () {
    test('全リスト空でも例外を投げない', () {
      final c = service.build(books: const [], reviews: const [], sessions: const [], now: () => now);
      expect(c.totalCount, kAchievementBadges.length);
      expect(c.earnedCount, 0);
      expect(c.isEmpty, isTrue);
      expect(c.completionRatio, 0.0);
    });

    test('ソートは category 昇順 → requiredCount 昇順 → id 昇順', () {
      final c = service.build(books: const [], reviews: const [], sessions: const [], now: () => now);
      for (var i = 0; i < c.progresses.length - 1; i++) {
        final a = c.progresses[i].definition;
        final b = c.progresses[i + 1].definition;
        final keyA = (a.category.index, a.requiredCount, a.id);
        final keyB = (b.category.index, b.requiredCount, b.id);
        final cmp = keyA.$1 != keyB.$1
            ? keyA.$1.compareTo(keyB.$1)
            : keyA.$2 != keyB.$2
                ? keyA.$2.compareTo(keyB.$2)
                : keyA.$3.compareTo(keyB.$3);
        expect(cmp, lessThanOrEqualTo(0), reason: '${a.id} must precede ${b.id}');
      }
    });

    test('summaryLabel は "6 / 15 獲得" 形式', () {
      final c = service.build(
        books: [book('1')],
        reviews: const [],
        sessions: const [],
        now: () => now,
      );
      expect(c.earnedCount, 1);
      expect(c.summaryLabel, '1 / ${kAchievementBadges.length} 獲得');
    });

    test('groupByCategory は宣言順・空カテゴリも含む', () {
      final c = service.build(books: const [], reviews: const [], sessions: const [], now: () => now);
      expect(c.groupByCategory.keys.toList(), AchievementCategory.values);
    });

    test('earned / unearned の整合', () {
      final c = service.build(
        books: [book('1')],
        reviews: [review('r1')],
        sessions: const [],
        now: () => now,
      );
      expect(c.earned.length + c.unearned.length, c.totalCount);
      expect(c.earned.every((p) => p.isEarned), isTrue);
      expect(c.unearned.any((p) => p.isEarned), isFalse);
    });

    test('now 未指定でも動作する', () {
      final c = service.build(books: const [], reviews: const [], sessions: const []);
      expect(c.totalCount, kAchievementBadges.length);
    });
  });

  group('kAchievementBadges', () {
    test('12〜16件・id 形式・一意', () {
      expect(kAchievementBadges.length, inInclusiveRange(12, 16));
      final ids = kAchievementBadges.map((d) => d.id).toSet();
      expect(ids.length, kAchievementBadges.length);
      for (final d in kAchievementBadges) {
        expect(d.id, matches(RegExp(r'^[a-z0-9_]+$')));
      }
    });

    test('規定のバッジ構成', () {
      int count(AchievementCategory category) =>
          kAchievementBadges.where((d) => d.category == category).length;
      expect(count(AchievementCategory.reading), 4);
      expect(count(AchievementCategory.streak), 3);
      expect(count(AchievementCategory.genre), 2);
      expect(count(AchievementCategory.review), 3);
      expect(count(AchievementCategory.time), 2);
    });
  });
}
