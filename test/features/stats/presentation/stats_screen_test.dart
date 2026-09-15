import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

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

Review review(String id, String bookId, {int rating = 4, int month = 5}) {
  return Review(
    id: id,
    bookId: bookId,
    rating: rating,
    text: 'text',
    createdAt: DateTime(DateTime.now().year, month, 10),
  );
}

Book finishedBook(String id, String author, int month) {
  return Book(
    id: id,
    title: '本$id',
    author: author,
    isbn: '',
    readingStatus: ReadingStatus.finished,
    finishedAt: DateTime(DateTime.now().year, month, 10),
  );
}

void main() {
  group('StatsViewModel', () {
    test('load で統計を算出する', () async {
      final vm = StatsViewModel();
      await vm.load(FakeStatsSource(
        books: [finishedBook('b1', '夏目', 3)],
        reviews: [review('r1', 'b1', rating: 5)],
      ));
      expect(vm.isLoading, isFalse);
      expect(vm.stats, isNotNull);
      expect(vm.stats!.totalFinished, 1);
      expect(vm.stats!.averageRating, 5.0);
      expect(vm.error, isNull);
    });

    test('load 失敗時は error を設定する', () async {
      final vm = StatsViewModel();
      await vm.load(_ThrowingSource());
      expect(vm.isLoading, isFalse);
      expect(vm.error, isNotNull);
      expect(vm.stats, isNull);
    });
  });

  group('StatsScreen', () {
    Future<void> pumpScreen(WidgetTester tester, StatsDataSource source) async {
      await tester.pumpWidget(
        MaterialApp(home: StatsScreen(dataSource: source)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('タイトルとサマリを表示する', (tester) async {
      await pumpScreen(
        tester,
        FakeStatsSource(
          books: [
            finishedBook('b1', '夏目', 3),
            finishedBook('b2', '夏目', 4),
          ],
          reviews: [review('r1', 'b1', rating: 5)],
        ),
      );
      expect(find.text('読書統計'), findsOneWidget);
      expect(find.textContaining('2 冊'), findsWidgets);
      expect(find.textContaining('夏目'), findsWidgets);
      expect(find.textContaining('5.0'), findsWidgets);
    });

    testWidgets('月別読了バーを表示する', (tester) async {
      await pumpScreen(
        tester,
        FakeStatsSource(books: [finishedBook('b1', '夏目', 3)]),
      );
      expect(find.byKey(const Key('stats_monthly_bar')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('stats_monthly_bar')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('空状態のメッセージを表示する', (tester) async {
      await pumpScreen(tester, FakeStatsSource());
      expect(find.text('まだ読了データがありません。'), findsOneWidget);
    });

    testWidgets('エラー状態のメッセージを表示する', (tester) async {
      await pumpScreen(tester, _ThrowingSource());
      await tester.pumpAndSettle();
      expect(find.text('統計の読み込みに失敗しました。'), findsOneWidget);
    });
  });
}

class _ThrowingSource implements StatsDataSource {
  @override
  Future<List<Book>> getBooks() async => throw StateError('boom');

  @override
  Future<List<Review>> getAllReviews() async => throw StateError('boom');
}
