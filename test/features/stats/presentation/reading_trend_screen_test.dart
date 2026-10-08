import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/presentation/reading_trend_screen.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

/// 決定論化のための統計基準日。
final DateTime _now = DateTime(2026, 6, 1);

class _FakeTrendSource implements TrendDataSource {
  final List<Book> books;
  final List<Review> reviews;
  final List<ReadingSession> sessions;
  _FakeTrendSource({
    List<Book>? books,
    List<Review>? reviews,
    List<ReadingSession>? sessions,
  })  : books = books ?? [],
        reviews = reviews ?? [],
        sessions = sessions ?? [];

  @override
  Future<List<Book>> getBooks() async => books;

  @override
  Future<List<Review>> getAllReviews() async => reviews;

  @override
  Future<List<ReadingSession>> getSessions() async => sessions;
}

Book _finishedBook(
  String id, {
  int month = 3,
  List<String> genres = const ['小説'],
}) {
  return Book(
    id: id,
    title: '本$id',
    author: '夏目',
    isbn: '',
    readingStatus: ReadingStatus.finished,
    finishedAt: DateTime(_now.year, month, 15),
    genres: genres,
  );
}

ReadingSession _session(String id, {int month = 5, int minutes = 60}) {
  return ReadingSession(
    id: id,
    startedAt: DateTime(_now.year, month, 10, 20),
    durationMinutes: minutes,
  );
}

void main() {
  /// 読了2冊（3月）＋セッション2本（5月・120分）の標準データ。
  TrendDataSource standardSource() => _FakeTrendSource(
        books: [
          _finishedBook('b1'),
          _finishedBook('b2'),
        ],
        reviews: const [],
        sessions: [
          _session('s1', month: 5),
          _session('s2', month: 5),
        ],
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    TrendDataSource source,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingTrendScreen(dataSource: source, now: () => _now),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// ローディング状態を観測できるよう未来で解決するデータソース。
  _DelayedTrendSource delayedSource(TrendDataSource inner) =>
      _DelayedTrendSource(inner);

  group('ReadingTrendScreen 表示遷移', () {
    testWidgets('初期はローディングを表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingTrendScreen(
            dataSource: delayedSource(standardSource()),
            now: () => _now,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(AppKeys.readingTrendLoading), findsOneWidget);
    });

    testWidgets('ローディング後にサマリーへ遷移する', (tester) async {
      final source = delayedSource(standardSource());
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingTrendScreen(dataSource: source, now: () => _now),
        ),
      );
      await tester.pump();
      expect(find.byKey(AppKeys.readingTrendLoading), findsOneWidget);
      source.completeAll();
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.readingTrendLoading), findsNothing);
      expect(find.byKey(AppKeys.readingTrendSummary), findsOneWidget);
    });
  });

  group('ReadingTrendScreen 空状態', () {
    testWidgets('空状態のメッセージを表示する', (tester) async {
      await pumpScreen(tester, _FakeTrendSource());
      expect(find.byKey(AppKeys.readingTrendEmpty), findsOneWidget);
      expect(find.text('この年の読書記録がありません'), findsOneWidget);
    });
  });

  group('ReadingTrendScreen サマリー', () {
    testWidgets('読了冊数を表示する', (tester) async {
      await pumpScreen(tester, standardSource());
      expect(find.text('読了 2 冊'), findsOneWidget);
    });

    testWidgets('総読書時間を表示する', (tester) async {
      await pumpScreen(tester, standardSource());
      expect(find.text('総読書時間 2時間'), findsOneWidget);
    });

    testWidgets('最多読了月を表示する', (tester) async {
      await pumpScreen(tester, standardSource());
      expect(find.text('最多読了月: 3月'), findsOneWidget);
    });

    testWidgets('読了0なら最多読了月を表示しない', (tester) async {
      await pumpScreen(
        tester,
        _FakeTrendSource(sessions: [_session('s1')]),
      );
      expect(find.textContaining('最多読了月'), findsNothing);
    });

    testWidgets('対象年の見出しを表示する', (tester) async {
      await pumpScreen(tester, standardSource());
      expect(find.text('2026年の読書'), findsOneWidget);
    });
  });

  group('ReadingTrendScreen チャート', () {
    testWidgets('棒グラフ・折れ線グラフ・円グラフを出現させる', (tester) async {
      await pumpScreen(tester, standardSource());
      expect(
        find.byKey(AppKeys.readingTrendFinishedChart),
        findsOneWidget,
      );
      expect(
        find.byKey(AppKeys.readingTrendMinutesChart),
        findsOneWidget,
      );
      expect(
        find.byKey(AppKeys.readingTrendGenreChart),
        findsOneWidget,
      );
    });

    testWidgets('円グラフウィジェットが描画される', (tester) async {
      await pumpScreen(tester, standardSource());
      expect(
        find.descendant(
          of: find.byKey(AppKeys.readingTrendGenreChart),
          matching: find.byType(PieChart),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ジャンル分布が空なら円グラフを出さない', (tester) async {
      await pumpScreen(
        tester,
        _FakeTrendSource(sessions: [_session('s1')]),
      );
      expect(find.byKey(AppKeys.readingTrendGenreChart), findsNothing);
    });

    testWidgets('棒グラフ内に BarChart を描画する', (tester) async {
      await pumpScreen(tester, standardSource());
      expect(
        find.descendant(
          of: find.byKey(AppKeys.readingTrendFinishedChart),
          matching: find.byType(BarChart),
        ),
        findsOneWidget,
      );
    });

    testWidgets('折れ線グラフ内に LineChart を描画する', (tester) async {
      await pumpScreen(tester, standardSource());
      expect(
        find.descendant(
          of: find.byKey(AppKeys.readingTrendMinutesChart),
          matching: find.byType(LineChart),
        ),
        findsOneWidget,
      );
    });

    testWidgets('複数ジャンルでも円グラフを描画する', (tester) async {
      await pumpScreen(
        tester,
        _FakeTrendSource(
          books: [
            _finishedBook('b1', genres: const ['小説']),
            _finishedBook('b2', genres: const ['SF']),
          ],
          sessions: [_session('s1')],
        ),
      );
      expect(find.byKey(AppKeys.readingTrendGenreChart), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(AppKeys.readingTrendGenreChart),
          matching: find.byType(PieChart),
        ),
        findsOneWidget,
      );
    });
  });

  group('ReadingTrendScreen 配線', () {
    testWidgets('StatsScreen の導線から遷移する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatsScreen(
            dataSource: _FakeStatsSource(
              books: [
                Book(
                  id: 'b1',
                  title: '本1',
                  author: '夏目',
                  isbn: '',
                  readingStatus: ReadingStatus.finished,
                  finishedAt: DateTime(_now.year, 3, 15),
                  genres: const ['小説'],
                ),
              ],
            ),
            trendDataSource: standardSource(),
            now: () => _now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.readingTrendEntry));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.readingTrendScreen), findsOneWidget);
      expect(find.byKey(AppKeys.readingTrendSummary), findsOneWidget);
    });
  });
}

class _FakeStatsSource implements StatsDataSource {
  final List<Book> books;
  final List<Review> reviews;
  _FakeStatsSource({List<Book>? books, List<Review>? reviews})
      : books = books ?? [],
        reviews = reviews ?? [];

  @override
  Future<List<Book>> getBooks() async => books;

  @override
  Future<List<Review>> getAllReviews() async => reviews;
}

/// 各取得を Completer で遅延させるラッパー（ローディング観測用）。
class _DelayedTrendSource implements TrendDataSource {
  final TrendDataSource _inner;
  final _completers = <Completer<void>>[];

  _DelayedTrendSource(this._inner);

  Future<void> _gate() {
    final completer = Completer<void>();
    _completers.add(completer);
    return completer.future;
  }

  /// 蓄積した全ゲートを解放する。
  void completeAll() {
    for (final completer in _completers) {
      if (!completer.isCompleted) completer.complete();
    }
  }

  @override
  Future<List<Book>> getBooks() async {
    await _gate();
    return _inner.getBooks();
  }

  @override
  Future<List<Review>> getAllReviews() async {
    await _gate();
    return _inner.getAllReviews();
  }

  @override
  Future<List<ReadingSession>> getSessions() async {
    await _gate();
    return _inner.getSessions();
  }
}