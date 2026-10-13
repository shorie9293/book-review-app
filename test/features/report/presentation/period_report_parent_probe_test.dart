// 親探針: 画面→サービス→表示の合成不変条件（子の試練が個別にしか撃たない箇所）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/report/domain/period_report_service.dart';
import 'package:book_review_app/features/report/domain/report_period.dart';
import 'package:book_review_app/features/report/presentation/period_report_screen.dart';

DateTime _now() => DateTime(2026, 10, 13, 9, 0); // 2026-10-13（火）

Book _finished(String id, String title, DateTime? finishedAt) => Book(
      id: id,
      title: title,
      author: '著者$id',
      isbn: 'isbn-$id',
      readingStatus: ReadingStatus.finished,
      finishedAt: finishedAt,
    );

Review _review(String id, String bookId, int rating, DateTime createdAt) =>
    Review(
      id: id,
      bookId: bookId,
      rating: rating,
      text: 'レビュー$id',
      createdAt: createdAt,
    );

ReadingSession _session(String id, DateTime startedAt, int minutes) =>
    ReadingSession(id: id, startedAt: startedAt, durationMinutes: minutes);

class _Fake implements PeriodReportDataSource {
  final List<Book> books;
  final List<Review> reviews;
  final List<ReadingSession> sessions;
  _Fake({this.books = const [], this.reviews = const [], this.sessions = const []});

  @override
  Future<List<Book>> getBooks() async => books;
  @override
  Future<List<Review>> getAllReviews() async => reviews;
  @override
  Future<List<ReadingSession>> getSessions() async => sessions;
}

Future<void> _pump(WidgetTester tester, PeriodReportDataSource src) async {
  await tester.pumpWidget(MaterialApp(
    home: PeriodReportScreen(dataSource: src, now: _now),
  ));
  await tester.pump();
}

String _textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  // 今週=10/12(月)〜10/18(日) / 前週=10/5(月)〜10/11(日)
  final books = <Book>[
    _finished('b1', '本A', DateTime(2026, 10, 13, 8)), // 今週・基準(09:00)以前
    _finished('b2', '本B', DateTime(2026, 10, 5, 12)),  // 前週の月曜ちょうど
    _finished('b3', '本C', null),                       // 読了日不明→除外
  ];
  final sessions = <ReadingSession>[
    _session('s1', DateTime(2026, 10, 12, 8), 30),  // 今週の月曜ちょうど
    _session('s2', DateTime(2026, 10, 5, 8), 45),   // 前週の月曜ちょうど
    _session('s3', DateTime(2026, 10, 20, 8), 60),  // 来週=未来→除外
  ];
  final reviews = <Review>[
    _review('r1', 'b1', 5, DateTime(2026, 10, 13, 9)), // 今週・★5
    _review('r2', 'b2', 3, DateTime(2026, 10, 6, 9)),  // 前週・★3（お気に入り外）
  ];

  testWidgets('探針1: 画面表示がサービスの独立計算値と一致する（合成）', (tester) async {
    final src = _Fake(books: books, reviews: reviews, sessions: sessions);
    await _pump(tester, src);

    // サービスを画面とは独立に呼んで期待値を導出する
    final expected = const PeriodReportService().build(
      books: books,
      reviews: reviews,
      sessions: sessions,
      period: ReportPeriod.weekOf(_now()),
      now: _now(),
    );

    expect(_textOf(tester, AppKeys.periodReportFinishedCount),
        '${expected.finishedCount} 冊');
    expect(_textOf(tester, AppKeys.periodReportTotalMinutes),
        expected.totalMinutesLabel);
    expect(_textOf(tester, AppKeys.periodReportPeriodLabel),
        expected.period.label);
    // 今週: 読了1冊・30分・★5レビュー1件
    expect(_textOf(tester, AppKeys.periodReportFinishedCount), '1 冊');
    expect(_textOf(tester, AppKeys.periodReportTotalMinutes), '30分');
    expect(find.byKey(AppKeys.periodReportFavoriteReview(0)), findsOneWidget);
    expect(find.byKey(AppKeys.periodReportFavoriteReview(1)), findsNothing);
  });

  testWidgets('探針2: 前へで前週の実データに切り替わる（期間送りの合成）', (tester) async {
    final src = _Fake(books: books, reviews: reviews, sessions: sessions);
    await _pump(tester, src);
    expect(_textOf(tester, AppKeys.periodReportTotalMinutes), '30分');

    await tester.tap(find.byKey(AppKeys.periodReportPrevButton));
    await tester.pump(); // _reload の Future 完了
    await tester.pump();

    // 前週: 読了1冊(b2)・45分(s2)・未来分(s3)は出ない
    expect(_textOf(tester, AppKeys.periodReportFinishedCount), '1 冊');
    expect(_textOf(tester, AppKeys.periodReportTotalMinutes), '45分');
    expect(_textOf(tester, AppKeys.periodReportPeriodLabel),
        '2026年10月5日〜10月11日');
  });

  testWidgets('探針3: 月次トグルで月全体を集計する', (tester) async {
    final src = _Fake(books: books, reviews: reviews, sessions: sessions);
    await _pump(tester, src);

    await tester.tap(find.byKey(AppKeys.periodReportRangeMonth));
    await tester.pump();
    await tester.pump();

    // 2026年10月: 読了2冊(b1,b2)・75分(s1+s2)・未来(s3)除外
    expect(_textOf(tester, AppKeys.periodReportPeriodLabel), '2026年10月');
    expect(_textOf(tester, AppKeys.periodReportFinishedCount), '2 冊');
    expect(_textOf(tester, AppKeys.periodReportTotalMinutes), '1時間15分');
  });

  testWidgets('探針4: 記録なき期間は空状態を出す', (tester) async {
    final src = _Fake(); // 全て空
    await _pump(tester, src);
    expect(find.byKey(AppKeys.periodReportEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.periodReportFinishedCount), findsNothing);
  });
}
