import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/domain/reading_trend.dart';
import 'package:book_review_app/features/stats/presentation/reading_trend_screen.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

/// 親（イシコリドメ）が撃つ合成の不変条件の探針。
///
/// 眷属の試練は個別機能（月別集計・ジャンル正規化・チャート出現）を撃つが、
/// 「画面に描かれたチャートの実データが集計結果と一致するか」「複数年データから
/// 対象年だけが描かれるか」という合成は誰も撃たない。ここでそれを撃つ。
void main() {
  final DateTime now = DateTime(2026, 6, 1);

  Book finishedBook(String id, {int month = 3, List<String> genres = const ['小説']}) {
    return Book(
      id: id,
      title: '本$id',
      author: '夏目',
      isbn: '',
      readingStatus: ReadingStatus.finished,
      finishedAt: DateTime(now.year, month, 15),
      genres: genres,
    );
  }

  ReadingSession session(
    String id, {
    int year = 2026,
    int month = 5,
    int minutes = 60,
  }) {
    return ReadingSession(
      id: id,
      startedAt: DateTime(year, month, 10, 20),
      durationMinutes: minutes,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    _FakeTrendSource source,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingTrendScreen(dataSource: source, now: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  BarChart barChart(WidgetTester tester) => tester.widget<BarChart>(
        find.descendant(
          of: find.byKey(AppKeys.readingTrendFinishedChart),
          matching: find.byType(BarChart),
        ),
      );

  LineChart lineChart(WidgetTester tester) => tester.widget<LineChart>(
        find.descendant(
          of: find.byKey(AppKeys.readingTrendMinutesChart),
          matching: find.byType(LineChart),
        ),
      );

  PieChart pieChart(WidgetTester tester) => tester.widget<PieChart>(
        find.descendant(
          of: find.byKey(AppKeys.readingTrendGenreChart),
          matching: find.byType(PieChart),
        ),
      );

  testWidgets('合成: 画面のチャート実データが ReadingTrendService の集計と一致する', (tester) async {
    final books = [
      finishedBook('b1', month: 1),
      finishedBook('b2', month: 7),
      finishedBook('b3', month: 7),
    ];
    final reviews = <Review>[];
    final sessions = [
      session('s1', month: 1, minutes: 30),
      session('s2', month: 7, minutes: 90),
    ];

    final expected = const ReadingTrendService().compute(
      books: books,
      reviews: reviews,
      sessions: sessions,
      now: now,
    );

    await pump(
      tester,
      _FakeTrendSource(books: books, reviews: reviews, sessions: sessions),
    );

    // 棒グラフの toY が monthlyFinished と一致
    final bars = barChart(tester).data.barGroups;
    expect(bars.length, 12);
    for (var i = 0; i < 12; i++) {
      expect(bars[i].barRods.single.toY, expected.monthlyFinished[i].toDouble());
    }

    // 折れ線の Y が monthlyMinutes と一致
    final spots = lineChart(tester).data.lineBarsData.single.spots;
    expect(spots.length, 12);
    for (var i = 0; i < 12; i++) {
      expect(spots[i].y, expected.monthlyMinutes[i].toDouble());
    }

    // サマリーの表示値が集計値と一致
    expect(find.text('読了 ${expected.totalFinished} 冊'), findsOneWidget);
    expect(find.text('総読書時間 ${expected.totalMinutesLabel}'), findsOneWidget);
  });

  testWidgets('合成: 対象年全体を集計し、前年・翌年の記録を混入させない', (tester) async {
    final books = [
      finishedBook('b-this', month: 2),
      Book(
        id: 'b-last',
        title: '昨年の本',
        author: '夏目',
        isbn: '',
        readingStatus: ReadingStatus.finished,
        finishedAt: DateTime(now.year - 1, 11, 1),
      ),
      Book(
        id: 'b-next',
        title: '来年の本',
        author: '夏目',
        isbn: '',
        readingStatus: ReadingStatus.finished,
        finishedAt: DateTime(now.year + 1, 1, 1),
      ),
    ];
    final sessions = [
      session('s-this', month: 1, minutes: 45),
      session('s-last', year: now.year - 1, month: 12, minutes: 999),
      session('s-next', year: now.year + 1, month: 1, minutes: 999),
    ];

    await pump(tester, _FakeTrendSource(books: books, sessions: sessions));

    // 読了冊数は今年の1冊のみ（1月のセッションも含む＝直近でなく年間集計）
    expect(find.text('読了 1 冊'), findsOneWidget);
    expect(find.text('総読書時間 45分'), findsOneWidget);

    final spots = lineChart(tester).data.lineBarsData.single.spots;
    final total = spots.fold<double>(0, (sum, s) => sum + s.y);
    expect(total, 45);
    expect(spots[0].y, 45);
  });

  testWidgets('合成: 表記ゆれジャンルは正規化されて1セクションへ統合される', (tester) async {
    await pump(
      tester,
      _FakeTrendSource(
        books: [
          finishedBook('b1', genres: const ['SF']),
          finishedBook('b2', genres: const ['sf']),
          finishedBook('b3', genres: const ['ＳＦ']),
        ],
      ),
    );

    final sections = pieChart(tester).data.sections;
    expect(sections.length, 1);
    expect(sections.single.value, 3);
  });

  testWidgets('合成: 円グラフのセクションは件数降順で最多ジャンルが先頭', (tester) async {
    await pump(
      tester,
      _FakeTrendSource(
        books: [
          finishedBook('b1', genres: const ['SF']),
          finishedBook('b2', genres: const ['小説']),
          finishedBook('b3', genres: const ['小説']),
          finishedBook('b4', genres: const ['歴史']),
        ],
      ),
    );

    final sections = pieChart(tester).data.sections;
    expect(sections.length, 3);
    expect(sections.first.title, '小説');
    expect(sections.first.value, 2);
    expect(sections.map((s) => s.value).toList(), [2, 1, 1]);
  });

  testWidgets('合成: ジャンル未設定の読了本は未分類セクションとして可視化される', (tester) async {
    await pump(
      tester,
      _FakeTrendSource(
        books: [
          finishedBook('b1', genres: const []),
          finishedBook('b2', genres: const []),
        ],
      ),
    );

    final sections = pieChart(tester).data.sections;
    expect(sections.length, 1);
    expect(sections.single.title, '未分類');
    expect(sections.single.value, 2);
  });

  testWidgets('合成: StatsScreen の導線が trendDataSource のデータを遷移先へ橋渡しする', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatsScreen(
          dataSource: _FakeStatsSource(
            books: [finishedBook('sb1', month: 4)],
          ),
          trendDataSource: _FakeTrendSource(
            books: [
              finishedBook('t1', month: 4),
              finishedBook('t2', month: 4),
              finishedBook('t3', month: 4),
            ],
            sessions: [session('ts1', minutes: 120)],
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.readingTrendEntry));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.readingTrendScreen), findsOneWidget);
    // 遷移先は StatsScreen の dataSource ではなく trendDataSource のデータを表示する
    expect(find.text('読了 3 冊'), findsOneWidget);
    expect(find.text('総読書時間 2時間'), findsOneWidget);
  });
}

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
