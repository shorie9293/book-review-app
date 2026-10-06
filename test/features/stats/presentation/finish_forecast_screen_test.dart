import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/domain/reading_pace.dart';
import 'package:book_review_app/features/stats/presentation/finish_forecast_screen.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/finish_forecast_view_model.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

class FakeForecastSource implements FinishForecastDataSource {
  final List<Book> books;
  final List<ReadingSession> sessions;
  final bool shouldThrow;

  FakeForecastSource({
    this.books = const [],
    this.sessions = const [],
    this.shouldThrow = false,
  });

  @override
  Future<List<Book>> getBooks() async {
    if (shouldThrow) throw Exception('boom');
    return books;
  }

  @override
  Future<List<ReadingSession>> getSessions() async => sessions;
}

class FakeStatsSource implements StatsDataSource {
  @override
  Future<List<Book>> getBooks() async => const [];

  @override
  Future<List<Review>> getAllReviews() async => const [];
}

final DateTime fixedNow = DateTime(2026, 10, 6, 12);

Book readingBook(String id, {int pageCount = 100, int currentPage = 50}) {
  return Book(
    id: id,
    title: '本$id',
    author: '著者$id',
    isbn: '',
    pageCount: pageCount,
    readingStatus: ReadingStatus.reading,
    currentPage: currentPage,
  );
}

ReadingSession session(String id, String bookId, DateTime at) {
  return ReadingSession(
    id: id,
    bookId: bookId,
    startedAt: at,
    durationMinutes: 30,
  );
}

FinishForecast okForecast(String bookId, {ReadingPaceStatus? status}) {
  return FinishForecast(
    bookId: bookId,
    title: '本$bookId',
    currentPage: 100,
    pageCount: 200,
    remainingPages: 100,
    pagesPerDay: 10,
    daysRemaining: 10,
    finishDate: DateTime(2026, 10, 16),
    status: status ?? ReadingPaceStatus.ok,
  );
}

void main() {
  group('FinishForecastViewModel', () {
    test('load で読了予測を算出する（clock 注入）', () async {
      final vm = FinishForecastViewModel(clock: () => fixedNow);
      await vm.load(FakeForecastSource(
        books: [readingBook('b1')],
        sessions: [session('s1', 'b1', fixedNow.subtract(const Duration(days: 10)))],
      ));
      expect(vm.isLoading, isFalse);
      expect(vm.error, isNull);
      expect(vm.forecasts, isNotNull);
      expect(vm.forecasts!.length, 1);
      expect(vm.forecasts!.first.status, ReadingPaceStatus.ok);
      expect(vm.forecasts!.first.daysRemaining, 10);
    });

    test('読了済み・未読の本は対象外、読書中のみ並ぶ', () async {
      final vm = FinishForecastViewModel(clock: () => fixedNow);
      await vm.load(FakeForecastSource(
        books: [
          readingBook('b1'),
          Book(
            id: 'b2',
            title: '本b2',
            author: '著者b2',
            isbn: '',
            readingStatus: ReadingStatus.finished,
          ),
          Book(
            id: 'b3',
            title: '本b3',
            author: '著者b3',
            isbn: '',
            readingStatus: ReadingStatus.unread,
          ),
        ],
        sessions: [session('s1', 'b1', fixedNow.subtract(const Duration(days: 10)))],
      ));
      expect(vm.forecasts!.map((f) => f.bookId), ['b1']);
    });

    test('load 失敗時は error を設定する', () async {
      final vm = FinishForecastViewModel(clock: () => fixedNow);
      await vm.load(FakeForecastSource(shouldThrow: true));
      expect(vm.isLoading, isFalse);
      expect(vm.forecasts, isNull);
      expect(vm.error, isNotNull);
    });

    test('空データでは空リストになる', () async {
      final vm = FinishForecastViewModel(clock: () => fixedNow);
      await vm.load(FakeForecastSource());
      expect(vm.forecasts, isEmpty);
    });
  });

  group('FinishForecastScreen', () {
    Future<void> pumpWith(
      WidgetTester tester,
      Widget child, {
      Duration duration = const Duration(milliseconds: 100),
    }) async {
      await tester.pumpWidget(MaterialApp(home: child));
      await tester.pump(duration);
    }

    testWidgets('forecastsOverride でカードが表示される', (tester) async {
      await pumpWith(
        tester,
        FinishForecastScreen(
          forecastsOverride: [
            okForecast('b1'),
            okForecast('b2', status: ReadingPaceStatus.noPace),
          ],
        ),
      );
      expect(find.byKey(AppKeys.finishForecastScreen), findsOneWidget);
      expect(find.byKey(AppKeys.finishForecastCard('b1')), findsOneWidget);
      expect(find.byKey(AppKeys.finishForecastCard('b2')), findsOneWidget);
      expect(find.text('本b1'), findsOneWidget);
      expect(find.text('本b2'), findsOneWidget);
      expect(find.text('現在 100 / 200 ページ'), findsNWidgets(2));
      expect(find.text(okForecast('b1').summaryLabel), findsOneWidget);
      expect(
        find.text(okForecast('b2', status: ReadingPaceStatus.noPace).summaryLabel),
        findsOneWidget,
      );
      expect(find.byKey(AppKeys.finishForecastLoading), findsNothing);
      expect(find.byKey(AppKeys.finishForecastEmpty), findsNothing);
    });

    testWidgets('空リストでは空状態を出す', (tester) async {
      await pumpWith(
        tester,
        FinishForecastScreen(forecastsOverride: const []),
      );
      expect(find.byKey(AppKeys.finishForecastEmpty), findsOneWidget);
      expect(find.text('読書中の本がありません。'), findsOneWidget);
      expect(find.byKey(AppKeys.finishForecastLoading), findsNothing);
    });

    testWidgets('ロード中はローディング表示、完了後にカードを出す', (tester) async {
      final completer = Completer<List<Book>>();
      await tester.pumpWidget(
        MaterialApp(
          home: FinishForecastScreen(
            dataSource: FakeForecastSourceWrapper(completer),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(AppKeys.finishForecastLoading), findsOneWidget);

      completer.complete([readingBook('b1')]);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(AppKeys.finishForecastLoading), findsNothing);
      expect(find.byKey(AppKeys.finishForecastCard('b1')), findsOneWidget);
    });

    testWidgets('ロード失敗後はエラー表示でクラッシュしない', (tester) async {
      await pumpWith(
        tester,
        FinishForecastScreen(
          dataSource: FakeForecastSource(shouldThrow: true),
          clock: () => fixedNow,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(AppKeys.finishForecastScreen), findsOneWidget);
    });
  });

  group('StatsScreen 導線', () {
    testWidgets('導線ボタンで読了予測画面へ遷移する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatsScreen(
            dataSource: FakeStatsSource(),
            forecastDataSource: FakeForecastSource(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.finishForecastOpenButton), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.finishForecastOpenButton));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.finishForecastScreen), findsOneWidget);
    });
  });
}

/// Completer で取得を遅延させるラッパー（ローディング検証用）。
class FakeForecastSourceWrapper implements FinishForecastDataSource {
  final Completer<List<Book>> booksCompleter;
  FakeForecastSourceWrapper(this.booksCompleter);

  @override
  Future<List<Book>> getBooks() => booksCompleter.future;

  @override
  Future<List<ReadingSession>> getSessions() async => const [];
}