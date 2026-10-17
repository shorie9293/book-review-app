import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/badges/presentation/badge_collection_screen.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

/// 統計画面と実績バッジ画面の双方のデータソースを兼ねる Fake。
class _FakeStatsAndBadgeDataSource
    implements StatsDataSource, BadgeCollectionDataSource {
  @override
  Future<List<Book>> getBooks() async => const [];

  @override
  Future<List<Review>> getAllReviews() async => const [];

  @override
  Future<List<Review>> getReviews() async => const [];

  @override
  Future<List<ReadingSession>> getSessions() async => const [];
}

void main() {
  testWidgets('統計画面 AppBar から実績バッジ画面へ遷移できる', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: StatsScreen(dataSource: _FakeStatsAndBadgeDataSource()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.badgeCollectionEntry), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.badgeCollectionEntry));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.badgeCollectionScreen), findsOneWidget);
    expect(find.text('実績バッジ'), findsOneWidget);
  });
}
