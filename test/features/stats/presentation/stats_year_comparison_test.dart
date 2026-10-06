import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

/// 決定論用の固定日時（実時計に依存しない）。
final DateTime _fixedNow = DateTime(2026, 6, 15);

class FakeStatsSource implements StatsDataSource {
  final List<Book> books;
  final List<Review> reviews;
  FakeStatsSource({List<Book>? books, List<Review>? reviews})
      : books = books ?? [],
        reviews = reviews ?? [];

  @override
  Future<List<Book>> getBooks() async => books;

  @override
  Future<List<Review>> getAllReviews() async => reviews;
}

Book finishedBook(String id, String author, DateTime finishedAt,
        {int? pageCount}) =>
    Book(
      id: id,
      title: '本$id',
      author: author,
      isbn: '',
      readingStatus: ReadingStatus.finished,
      finishedAt: finishedAt,
      pageCount: pageCount,
    );

Review review(String id, String bookId, DateTime createdAt, {int rating = 4}) =>
    Review(
      id: id,
      bookId: bookId,
      rating: rating,
      text: 'text',
      createdAt: createdAt,
    );

void main() {
  group('StatsViewModel 前年比', () {
    test('load 後に comparison が非null・current/previous.year が正しい', () async {
      final vm = StatsViewModel(now: () => _fixedNow);
      await vm.load(FakeStatsSource(
        books: [
          finishedBook('b1', '夏目', DateTime(2026, 3, 10), pageCount: 200),
          finishedBook('b2', '芥川', DateTime(2025, 5, 2), pageCount: 150),
        ],
        reviews: [
          review('r1', 'b1', DateTime(2026, 3, 11), rating: 5),
          review('r2', 'b2', DateTime(2025, 5, 3), rating: 4),
        ],
      ));
      final comparison = vm.comparison;
      expect(comparison, isNotNull);
      expect(comparison!.current.year, 2026);
      expect(comparison.previous.year, 2025);
      expect(comparison.hasPreviousData, isTrue);
      expect(comparison.finishedDiff, 0);
      expect(comparison.headLabel, '2025年 → 2026年');
    });

    test('now 未指定なら実時計でも load 後に comparison が非null', () async {
      final vm = StatsViewModel();
      await vm.load(FakeStatsSource(
        books: [finishedBook('b1', '夏目', DateTime(2020, 1, 1))],
      ));
      expect(vm.comparison, isNotNull);
    });

    test('load 失敗時は comparison が null', () async {
      final vm = StatsViewModel(now: () => _fixedNow);
      await vm.load(_ThrowingSource());
      expect(vm.comparison, isNull);
    });
  });

  group('StatsScreen 前年比カード', () {
    Future<void> pumpScreen(WidgetTester tester, StatsDataSource source) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: StatsScreen(
            dataSource: source,
            now: () => _fixedNow,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('前年比カードが末尾に表示される', (tester) async {
      await pumpScreen(
        tester,
        FakeStatsSource(
          books: [
            finishedBook('b1', '夏目', DateTime(2026, 3, 10), pageCount: 200),
            finishedBook('b2', '芥川', DateTime(2025, 5, 2), pageCount: 150),
          ],
          reviews: [
            review('r1', 'b1', DateTime(2026, 3, 11), rating: 5),
            review('r2', 'b2', DateTime(2025, 5, 3), rating: 4),
          ],
        ),
      );
      expect(
        find.byKey(AppKeys.statsYearComparison),
        findsOneWidget,
      );
      expect(find.textContaining('2025年 → 2026年'), findsOneWidget);
      expect(find.byKey(AppKeys.statsComparisonFinished), findsOneWidget);
      expect(find.byKey(AppKeys.statsComparisonPages), findsOneWidget);
      expect(find.byKey(AppKeys.statsComparisonAuthors), findsOneWidget);
      expect(find.textContaining('ページ'), findsWidgets);
      expect(find.textContaining('人'), findsWidgets);
    });

    testWidgets('前年データ0件でもカードが表示され落ちない', (tester) async {
      await pumpScreen(
        tester,
        FakeStatsSource(
          books: [
            finishedBook('b1', '夏目', DateTime(2026, 3, 10), pageCount: 200),
          ],
          reviews: [review('r1', 'b1', DateTime(2026, 3, 11), rating: 5)],
        ),
      );
      expect(find.byKey(AppKeys.statsYearComparison), findsOneWidget);
      expect(find.text('前年のデータがありません'), findsOneWidget);
    });
  });
}

class _ThrowingSource implements StatsDataSource {
  @override
  Future<List<Book>> getBooks() async => throw StateError('boom');

  @override
  Future<List<Review>> getAllReviews() async => throw StateError('boom');
}