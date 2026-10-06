import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/domain/reading_pace_service.dart';
import 'package:book_review_app/features/stats/presentation/finish_forecast_screen.dart';

/// 親探針: ドメイン層の出力（forecastAll）が UI 層で
/// 同一順序・同一ラベルで描画されるという「層をまたぐ合成の不変条件」を撃つ。
/// 眷属は層ごとに個別検証するため、両ラウンドの継ぎ目は親が実測せよ。
void main() {
  Book book({
    required String id,
    required String title,
    int? pageCount,
    int currentPage = 0,
    ReadingStatus status = ReadingStatus.reading,
  }) {
    return Book(
      id: id,
      title: title,
      author: '著者',
      isbn: id,
      pageCount: pageCount,
      currentPage: currentPage,
      readingStatus: status,
    );
  }

  ReadingSession session(String id, String bookId, DateTime at, int minutes) {
    return ReadingSession(
      id: id,
      bookId: bookId,
      startedAt: at,
      durationMinutes: minutes,
    );
  }

  testWidgets('探針: forecastAll の順序とラベルが画面にそのまま描画される', (tester) async {
    final now = DateTime(2026, 10, 6);
    final books = [
      book(id: 'a', title: 'Alpha', pageCount: 100, currentPage: 50),
      book(id: 'b', title: 'Beta', pageCount: 200, currentPage: 10),
      book(id: 'c', title: 'Gamma', pageCount: 100, status: ReadingStatus.unread),
    ];
    final sessions = [
      session('s1', 'a', DateTime(2026, 10, 5, 9), 30),
      session('s2', 'a', DateTime(2026, 10, 6, 9), 30),
      // b のセッションは存在しない → ペース推定不能
    ];

    final forecasts =
        const ReadingPaceService().forecastAll(books, sessions, now);

    // 不変条件1: 未読は除外・予測不能は末尾
    expect(forecasts.map((f) => f.bookId).toList(), ['a', 'b']);

    await tester.pumpWidget(
      MaterialApp(home: FinishForecastScreen(forecastsOverride: forecasts)),
    );
    await tester.pump();

    final cardA = find.byKey(AppKeys.finishForecastCard('a'));
    final cardB = find.byKey(AppKeys.finishForecastCard('b'));
    expect(cardA, findsOneWidget);
    expect(cardB, findsOneWidget);
    // 不変条件2: サービスが返した順序 = 描画順
    expect(
      tester.getTopLeft(cardA).dy < tester.getTopLeft(cardB).dy,
      isTrue,
      reason: 'サービス順（読了予測あり → 推定不能）で描画されていない',
    );
    // 不変条件3: summaryLabel がそのまま出る
    expect(find.text(forecasts.first.summaryLabel), findsOneWidget);
    expect(find.text('あと1日（2026/10/07）に読了見込み'), findsOneWidget);
    expect(find.text('読了予測あり'), findsOneWidget);
    expect(find.text('ペース推定不能'), findsOneWidget);
  });

  testWidgets('探針: 対象0件なら空状態のみ（カードを描画しない）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FinishForecastScreen(forecastsOverride: [])),
    );
    await tester.pump();
    expect(find.byKey(const Key('finish_forecast_empty')), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });
}
