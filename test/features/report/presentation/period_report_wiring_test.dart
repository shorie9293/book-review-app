// 統計画面 → 期間レポート画面の配線試練。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/report/presentation/period_report_screen.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

DateTime _now() => DateTime(2026, 10, 13, 9, 0);

class _FakeReportDataSource implements PeriodReportDataSource {
  @override
  Future<List<Book>> getBooks() async => const [];

  @override
  Future<List<Review>> getAllReviews() async => const [];

  @override
  Future<List<ReadingSession>> getSessions() async => const [];
}

class _EmptyStatsSource implements StatsDataSource {
  @override
  Future<List<Book>> getBooks() async => const [];

  @override
  Future<List<Review>> getAllReviews() async => const [];
}

void main() {
  testWidgets('統計画面に期間レポート導線キーが存在する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatsScreen(
          dataSource: _EmptyStatsSource(),
          periodReportDataSource: _FakeReportDataSource(),
          now: _now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.periodReportEntry), findsOneWidget);
  });

  testWidgets('導線タップで期間レポート画面へ遷移する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatsScreen(
          dataSource: _EmptyStatsSource(),
          periodReportDataSource: _FakeReportDataSource(),
          now: _now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.periodReportEntry));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.periodReportScreen), findsOneWidget);
    expect(find.text('期間レポート'), findsOneWidget);
  });
}
