// 期間レポート画面の試練。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/report/presentation/period_report_screen.dart';

DateTime _now() => DateTime(2026, 10, 13, 9, 0); // 2026-10-13（火）

Book _finishedBook(
  String id,
  String title, {
  DateTime? finishedAt,
}) {
  return Book(
    id: id,
    title: title,
    author: '著者$id',
    isbn: 'isbn-$id',
    readingStatus: ReadingStatus.finished,
    finishedAt: finishedAt,
  );
}

Review _review(String id, String bookId, int rating, DateTime createdAt) {
  return Review(
    id: id,
    bookId: bookId,
    rating: rating,
    text: 'レビュー$id',
    createdAt: createdAt,
  );
}

class _FakeDataSource implements PeriodReportDataSource {
  final List<Book> books;
  final List<Review> reviews;
  final List<ReadingSession> sessions;

  _FakeDataSource({
    this.books = const [],
    this.reviews = const [],
    this.sessions = const [],
  });

  @override
  Future<List<Book>> getBooks() async => books;

  @override
  Future<List<Review>> getAllReviews() async => reviews;

  @override
  Future<List<ReadingSession>> getSessions() async => sessions;
}

Future<void> _pumpWith(
  WidgetTester tester,
  PeriodReportDataSource source, {
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(home: PeriodReportScreen(dataSource: source, now: now)),
  );
  await tester.pump();
}

void main() {
  // 今週 = 2026-10-12(月)〜10-18(日)
  final weekLabel = '2026年10月12日〜10月18日';
  final prevWeekLabel = '2026年10月5日〜10月11日';
  final nextWeekLabel = '2026年10月19日〜10月25日';

  testWidgets('ローディング表示から内容表示へ遷移する', (tester) async {
    final source = _FakeDataSource(
      books: [_finishedBook('b1', '本A', finishedAt: DateTime(2026, 10, 13))],
    );
    await tester.pumpWidget(
      MaterialApp(home: PeriodReportScreen(dataSource: source, now: _now)),
    );
    // ローディング（Future完了前）
    expect(find.byKey(AppKeys.periodReportLoading), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.periodReportLoading), findsNothing);
    expect(find.byKey(AppKeys.periodReportFinishedCount), findsOneWidget);
  });

  testWidgets('初期表示は今週・週次の期間ラベル', (tester) async {
    await _pumpWith(tester, _FakeDataSource(), now: _now);
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(
      find.byKey(AppKeys.periodReportPeriodLabel),
    );
    expect(label.data, weekLabel);
  });

  testWidgets('月次トグルで期間ラベルが当月になる', (tester) async {
    await _pumpWith(tester, _FakeDataSource(), now: _now);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportRangeMonth));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(
      find.byKey(AppKeys.periodReportPeriodLabel),
    );
    expect(label.data, '2026年10月');
  });

  testWidgets('月次から週次へ戻すと今週のラベルに戻る', (tester) async {
    await _pumpWith(tester, _FakeDataSource(), now: _now);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportRangeMonth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportRangeWeek));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(
      find.byKey(AppKeys.periodReportPeriodLabel),
    );
    expect(label.data, weekLabel);
  });

  testWidgets('前へで前週の期間ラベルになる', (tester) async {
    await _pumpWith(tester, _FakeDataSource(), now: _now);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportPrevButton));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(
      find.byKey(AppKeys.periodReportPeriodLabel),
    );
    expect(label.data, prevWeekLabel);
  });

  testWidgets('次へで次週の期間ラベルになる', (tester) async {
    await _pumpWith(tester, _FakeDataSource(), now: _now);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportNextButton));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(
      find.byKey(AppKeys.periodReportPeriodLabel),
    );
    expect(label.data, nextWeekLabel);
  });

  testWidgets('前へ→次へで今週に戻る', (tester) async {
    await _pumpWith(tester, _FakeDataSource(), now: _now);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportPrevButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportNextButton));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(
      find.byKey(AppKeys.periodReportPeriodLabel),
    );
    expect(label.data, weekLabel);
  });

  testWidgets('月次の前へで前月の期間ラベルになる', (tester) async {
    await _pumpWith(tester, _FakeDataSource(), now: _now);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportRangeMonth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportPrevButton));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(
      find.byKey(AppKeys.periodReportPeriodLabel),
    );
    expect(label.data, '2026年9月');
  });

  testWidgets('期間移動後に内容が再計算される（前週の読了が反映）', (tester) async {
    final source = _FakeDataSource(
      books: [_finishedBook('b1', '前週の本', finishedAt: DateTime(2026, 10, 6))],
    );
    await _pumpWith(tester, source, now: _now);
    await tester.pumpAndSettle();
    // 今週は空
    expect(find.byKey(AppKeys.periodReportEmpty), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.periodReportPrevButton));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.periodReportEmpty), findsNothing);
    expect(find.text('前週の本'), findsOneWidget);
  });

  testWidgets('空データのとき空状態を表示する', (tester) async {
    await _pumpWith(tester, _FakeDataSource(), now: _now);
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.periodReportEmpty), findsOneWidget);
  });

  testWidgets('読了冊数を表示する', (tester) async {
    final source = _FakeDataSource(
      books: [
        _finishedBook('b1', '本A', finishedAt: DateTime(2026, 10, 13, 7)),
        _finishedBook('b2', '本B', finishedAt: DateTime(2026, 10, 12, 8)),
      ],
    );
    await _pumpWith(tester, source, now: _now);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(
      find.byKey(AppKeys.periodReportFinishedCount),
    );
    expect(text.data, '2 冊');
  });

  testWidgets('総読書時間を表示する（90分→1時間30分）', (tester) async {
    final source = _FakeDataSource(
      sessions: [
        ReadingSession(
          id: 's1',
          startedAt: DateTime(2026, 10, 13, 7),
          durationMinutes: 60,
        ),
        ReadingSession(
          id: 's2',
          startedAt: DateTime(2026, 10, 13, 8),
          durationMinutes: 30,
        ),
      ],
    );
    await _pumpWith(tester, source, now: _now);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(
      find.byKey(AppKeys.periodReportTotalMinutes),
    );
    expect(text.data, '1時間30分');
  });

  testWidgets('読了本リストを表示する', (tester) async {
    final source = _FakeDataSource(
      books: [_finishedBook('b1', '読了本A', finishedAt: DateTime(2026, 10, 13))],
    );
    await _pumpWith(tester, source, now: _now);
    await tester.pumpAndSettle();
    expect(find.text('読了本A'), findsOneWidget);
  });

  testWidgets('お気に入りレビュー行を表示する', (tester) async {
    final source = _FakeDataSource(
      reviews: [
        _review('r1', 'b1', 5, DateTime(2026, 10, 13, 8)),
        _review('r2', 'b1', 3, DateTime(2026, 10, 13, 8)), // 対象外
      ],
    );
    await _pumpWith(tester, source, now: _now);
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.periodReportFavoriteReview(0)), findsOneWidget);
    expect(find.byKey(AppKeys.periodReportFavoriteReview(1)), findsNothing);
    expect(find.text('レビューr1'), findsOneWidget);
  });

  testWidgets('未読本は読了リストに含まれない', (tester) async {
    final source = _FakeDataSource(
      books: [
        const Book(id: 'b1', title: '積読', author: 'x', isbn: 'i'),
      ],
    );
    await _pumpWith(tester, source, now: _now);
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.periodReportEmpty), findsOneWidget);
  });
}
