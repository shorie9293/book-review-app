import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/badges/presentation/badge_collection_screen.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

/// Fake データソース（Hive に一切触れない）。
class _FakeBadgeDataSource implements BadgeCollectionDataSource {
  final List<Book> books;
  final List<Review> reviews;
  final List<ReadingSession> sessions;
  final bool throwOnError;

  _FakeBadgeDataSource({
    this.books = const [],
    this.reviews = const [],
    this.sessions = const [],
    this.throwOnError = false,
  });

  @override
  Future<List<Book>> getBooks() async {
    if (throwOnError) throw Exception('boom');
    return books;
  }

  @override
  Future<List<Review>> getReviews() async {
    if (throwOnError) throw Exception('boom');
    return reviews;
  }

  @override
  Future<List<ReadingSession>> getSessions() async {
    if (throwOnError) throw Exception('boom');
    return sessions;
  }
}

DateTime _fixedNow() => DateTime(2026, 10, 17, 12);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required BadgeCollectionDataSource dataSource,
  DateTime Function()? now,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: BadgeCollectionScreen(dataSource: dataSource, now: now),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('サマリーラベルと獲得率バーを表示する', (tester) async {
    await _pumpScreen(tester, dataSource: _FakeBadgeDataSource());

    final summary = find.byKey(AppKeys.badgeSummaryLabel);
    expect(summary, findsOneWidget);
    final textWidget = tester.widget<Text>(summary);
    expect(textWidget.data, contains('/ 14 獲得'));

    final bar = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(LinearProgressIndicator),
    );
    expect(bar, findsWidgets);
  });

  testWidgets('獲得済み行はカテゴリアイコンと獲得済みラベルを表示する', (tester) async {
    final book = Book(
      id: 'b1',
      title: '本',
      author: '著者',
      isbn: '',
      readingStatus: ReadingStatus.finished,
    );
    await _pumpScreen(
      tester,
      dataSource: _FakeBadgeDataSource(books: [book]),
      now: _fixedNow,
    );

    final row = find.byKey(AppKeys.badgeRow('finished_1'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('最初の一冊')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('獲得済み')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock), findsWidgets);
  });

  testWidgets('未獲得行は残数ラベルを表示する', (tester) async {
    await _pumpScreen(
      tester,
      dataSource: _FakeBadgeDataSource(),
      now: _fixedNow,
    );

    final row = find.byKey(AppKeys.badgeRow('finished_5'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('あと5冊')),
      findsOneWidget,
    );
  });

  testWidgets('獲得済みフィルタで未獲得行が消える', (tester) async {
    await _pumpScreen(
      tester,
      dataSource: _FakeBadgeDataSource(),
      now: _fixedNow,
    );

    expect(find.byKey(AppKeys.badgeRow('finished_5')), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.badgeFilterEarned));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.badgeRow('finished_5')), findsNothing);
    expect(find.byKey(AppKeys.badgeFilterUnearned), findsOneWidget);
  });

  testWidgets('未獲得フィルタに戻すと未獲得行が再表示される', (tester) async {
    await _pumpScreen(
      tester,
      dataSource: _FakeBadgeDataSource(),
      now: _fixedNow,
    );

    await tester.tap(find.byKey(AppKeys.badgeFilterEarned));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.badgeRow('finished_5')), findsNothing);

    await tester.tap(find.byKey(AppKeys.badgeFilterAll));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.badgeRow('finished_5')), findsOneWidget);
  });

  testWidgets('3日連続セッションで streak_3 が獲得済みになる', (tester) async {
    final sessions = [
      ReadingSession(
        id: 's1',
        startedAt: DateTime(2026, 10, 15, 10),
        durationMinutes: 30,
      ),
      ReadingSession(
        id: 's2',
        startedAt: DateTime(2026, 10, 16, 10),
        durationMinutes: 30,
      ),
      ReadingSession(
        id: 's3',
        startedAt: DateTime(2026, 10, 17, 10),
        durationMinutes: 30,
      ),
    ];
    await _pumpScreen(
      tester,
      dataSource: _FakeBadgeDataSource(sessions: sessions),
      now: _fixedNow,
    );

    final row = find.byKey(AppKeys.badgeRow('streak_3'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('獲得済み')),
      findsOneWidget,
    );
  });

  testWidgets('読込失敗でも空状態を表示して落ちない', (tester) async {
    await _pumpScreen(
      tester,
      dataSource: _FakeBadgeDataSource(throwOnError: true),
    );

    expect(find.byKey(AppKeys.badgeEmpty), findsOneWidget);
  });

  testWidgets('レビュー1件で review_1 が獲得済みになる', (tester) async {
    final review = Review(
      id: 'r1',
      bookId: 'b1',
      rating: 4,
      text: 'よかった',
      createdAt: _fixedNow(),
    );
    await _pumpScreen(
      tester,
      dataSource: _FakeBadgeDataSource(reviews: [review]),
      now: _fixedNow,
    );

    final row = find.byKey(AppKeys.badgeRow('review_1'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('獲得済み')),
      findsOneWidget,
    );
  });
}
