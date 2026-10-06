import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/domain/reading_pace.dart';
import 'package:book_review_app/features/stats/domain/reading_pace_service.dart';

void main() {
  const service = ReadingPaceService();
  final now = DateTime(2026, 10, 6, 21);

  Book book({
    String id = 'b1',
    String title = '本',
    int? pageCount = 200,
    int currentPage = 100,
    String readingStatus = 'reading',
  }) {
    return Book(
      id: id,
      title: title,
      author: '著者',
      isbn: '',
      pageCount: pageCount,
      currentPage: currentPage,
      readingStatus: ReadingStatus.values.firstWhere(
        (s) => s.name == readingStatus,
      ),
    );
  }

  ReadingSession session(
    String id, {
    String? bookId = 'b1',
    required DateTime startedAt,
  }) {
    return ReadingSession(
      id: id,
      bookId: bookId,
      startedAt: startedAt,
      durationMinutes: 30,
    );
  }

  group('pagesPerDay', () {
    test('セッション無しは null', () {
      expect(service.pagesPerDay(const [], now), isNull);
    });

    test('単一セッション: 差は最低1日', () {
      final pace = service.pagesPerDay(
        [session('s1', startedAt: DateTime(2026, 10, 6, 10))],
        now,
        currentPage: 100,
      );
      expect(pace, 100.0);
    });

    test('複数セッション: 最初の日から now の日までの日差で割る', () {
      final pace = service.pagesPerDay(
        [
          session('s1', startedAt: DateTime(2026, 10, 1, 10)),
          session('s2', startedAt: DateTime(2026, 10, 4, 10)),
        ],
        now,
        currentPage: 100,
      );
      // 10/1 → 10/6 は5日差
      expect(pace, closeTo(100 / 5, 0.0001));
    });

    test('windowDays 外の古いセッションは除外される', () {
      final pace = service.pagesPerDay(
        [
          session('s1', startedAt: DateTime(2026, 9, 1, 10)),
          session('s2', startedAt: DateTime(2026, 10, 4, 10)),
        ],
        now,
        currentPage: 100,
      );
      // 10/4 → 10/6 は2日差（windowDays=14 で 9/1 は範囲外）
      expect(pace, closeTo(100 / 2, 0.0001));
    });

    test('windowDays=1 なら当日のセッションのみ', () {
      final pace = service.pagesPerDay(
        [
          session('s1', startedAt: DateTime(2026, 10, 1)),
          session('s2', startedAt: DateTime(2026, 10, 6, 8)),
        ],
        now,
        windowDays: 1,
        currentPage: 100,
      );
      expect(pace, 100.0);
    });

    test('currentPage が 0 なら null', () {
      final pace = service.pagesPerDay(
        [session('s1', startedAt: DateTime(2026, 10, 4))],
        now,
        currentPage: 0,
      );
      expect(pace, isNull);
    });
  });

  group('forecast', () {
    test('pageCount が null なら noPageCount', () {
      final f = service.forecast(book(pageCount: null), const [], now);
      expect(f.status, ReadingPaceStatus.noPageCount);
      expect(f.remainingPages, 0);
      expect(f.pagesPerDay, isNull);
      expect(f.daysRemaining, isNull);
      expect(f.finishDate, isNull);
    });

    test('pageCount が 0 以下なら noPageCount', () {
      final f = service.forecast(book(pageCount: 0), const [], now);
      expect(f.status, ReadingPaceStatus.noPageCount);
    });

    test('読了状態なら finished', () {
      final f = service.forecast(
        book(readingStatus: 'finished'),
        const [],
        now,
      );
      expect(f.status, ReadingPaceStatus.finished);
      expect(f.remainingPages, 0);
      expect(f.finishDate, isNull);
    });

    test('currentPage >= pageCount なら finished', () {
      final f = service.forecast(book(currentPage: 200), const [], now);
      expect(f.status, ReadingPaceStatus.finished);
    });

    test('セッション無しなら noPace（例外を投げない）', () {
      final f = service.forecast(book(), const [], now);
      expect(f.status, ReadingPaceStatus.noPace);
      expect(f.remainingPages, 100);
      expect(f.pagesPerDay, isNull);
      expect(f.daysRemaining, isNull);
      expect(f.finishDate, isNull);
      expect(f.bookId, 'b1');
      expect(f.title, '本');
    });

    test('ok: 残り日数は切り上げ、finishDate は当日+日数', () {
      final f = service.forecast(
        book(currentPage: 50, pageCount: 200),
        [session('s1', startedAt: DateTime(2026, 10, 1, 10))],
        now,
      );
      expect(f.status, ReadingPaceStatus.ok);
      // 50残読ではなく現ページ50 / 5日差 = 10ページ/日
      expect(f.pagesPerDay, closeTo(10.0, 0.0001));
      expect(f.daysRemaining, 15); // ceil(150/10)
      expect(f.finishDate, DateTime(2026, 10, 6).add(const Duration(days: 15)));
      expect(f.summaryLabel, 'あと15日（2026/10/21）に読了見込み');
    });

    test('切り上げ: 残り80・24ページ/日なら4日', () {
      final f = service.forecast(
        book(currentPage: 120, pageCount: 200),
        [session('s1', startedAt: DateTime(2026, 10, 1))],
        now,
      );
      // 120/5 = 24ページ/日、80/24 = 3.33 → ceil 4日
      expect(f.daysRemaining, 4);
    });

    test('当日開始のセッション: ペース=currentPage、残りに応じ日数', () {
      final f = service.forecast(
        book(currentPage: 10, pageCount: 60),
        [session('s1', startedAt: DateTime(2026, 10, 6, 8))],
        now,
      );
      expect(f.pagesPerDay, 10.0);
      expect(f.daysRemaining, 5); // ceil(50/10)
    });

    test('forecast 内で他書籍セッションを渡しても無視される', () {
      final f = service.forecast(
        book(currentPage: 50, pageCount: 200),
        [
          session('s0', bookId: 'other', startedAt: DateTime(2026, 10, 1)),
          session('s1', startedAt: DateTime(2026, 10, 1)),
        ],
        now,
      );
      expect(f.status, ReadingPaceStatus.ok);
      expect(f.pagesPerDay, closeTo(10.0, 0.0001));
    });
  });

  group('forecastAll', () {
    test('進行中のみ対象・finishDate 昇順・null は末尾', () {
      final okBook = book(id: 'b1', title: 'B', currentPage: 50);
      final noPaceBook = book(id: 'b2', title: 'A', currentPage: 10);
      final finishedBook = book(
        id: 'b3',
        title: 'C',
        readingStatus: 'finished',
      );
      final unreadBook = book(id: 'b4', title: 'D', readingStatus: 'unread');
      final sessions = [
        session('s2', bookId: 'b1', startedAt: DateTime(2026, 10, 1, 10)),
      ];

      final result = service.forecastAll(
        [noPaceBook, okBook, finishedBook, unreadBook],
        sessions,
        now,
      );

      expect(result.map((f) => f.bookId).toList(), ['b1', 'b2']);
      expect(result[0].status, ReadingPaceStatus.ok);
      expect(result[1].status, ReadingPaceStatus.noPace);
    });

    test('finishDate 同値は title 昇順→bookId 昇順', () {
      // 同じセッション構成で同一ペース・同一 finishDate になる3冊
      final a = book(id: 'id2', title: '同じ', currentPage: 50);
      final b = book(id: 'id1', title: '同じ', currentPage: 50);
      final c = book(id: 'id3', title: 'あ', currentPage: 50);
      final sessions = [
        session('s1', bookId: 'id2', startedAt: DateTime(2026, 10, 1)),
        session('s2', bookId: 'id1', startedAt: DateTime(2026, 10, 1)),
        session('s3', bookId: 'id3', startedAt: DateTime(2026, 10, 1)),
      ];

      final result = service.forecastAll([a, b, c], sessions, now);

      // 同一 finishDate → title 昇順（'あ' < '同じ'）→ title 同値なら bookId 昇順
      expect(result.map((f) => f.bookId).toList(), ['id3', 'id1', 'id2']);
      expect(result.map((f) => f.finishDate).toSet().length, 1);
    });

    test('noPace（finishDate=null）は ok の後ろに回る', () {
      final okBook = book(id: 'b1', title: 'Z', currentPage: 50);
      final noPaceBook = book(id: 'b2', title: 'A', currentPage: 10);
      final sessions = [
        session('s2', bookId: 'b1', startedAt: DateTime(2026, 10, 1, 10)),
      ];

      final result = service.forecastAll([noPaceBook, okBook], sessions, now);

      expect(result.map((f) => f.bookId).toList(), ['b1', 'b2']);
    });

    test('入力の books/sessions を破壊しない', () {
      final books = [book(id: 'b2', title: 'A', currentPage: 10)];
      final sessions = [
        session('s1', bookId: 'b2', startedAt: DateTime(2026, 10, 6, 8)),
      ];
      final booksLength = books.length;
      final sessionsLength = sessions.length;

      service.forecastAll(books, sessions, now);

      expect(books.length, booksLength);
      expect(sessions.length, sessionsLength);
    });
  });
}
