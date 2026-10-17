import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/badges/domain/achievement_badge_service.dart';
import 'package:book_review_app/features/badges/presentation/badge_collection_screen.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';

/// 親探針用 Fake（Hive に一切触れない）。
class _FakeSource implements BadgeCollectionDataSource {
  final List<Book> books;
  final List<Review> reviews;
  final List<ReadingSession> sessions;

  _FakeSource({
    this.books = const [],
    this.reviews = const [],
    this.sessions = const [],
  });

  @override
  Future<List<Book>> getBooks() async => books;

  @override
  Future<List<Review>> getReviews() async => reviews;

  @override
  Future<List<ReadingSession>> getSessions() async => sessions;
}

Book _finished(String id, {List<String> genres = const []}) => Book(
      id: id,
      title: '本$id',
      author: '著者',
      isbn: 'isbn$id',
      readingStatus: ReadingStatus.finished,
      genres: genres,
      finishedAt: DateTime(2026, 10, 1),
    );

Review _review(String id) => Review(
      id: id,
      bookId: 'b$id',
      rating: 4,
      text: '感想',
      createdAt: DateTime(2026, 10, 1),
    );

ReadingSession _session(String id, DateTime at, {int minutes = 30}) =>
    ReadingSession(id: id, startedAt: at, durationMinutes: minutes);

DateTime _now() => DateTime(2026, 10, 17, 12);

Future<void> _pump(WidgetTester tester, _FakeSource source) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: BadgeCollectionScreen(dataSource: source, now: _now),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // 探針1: 画面のサマリーと行数が、同じ入力に対するサービス出力と完全一致する
  // （画面が独自集計していないことの合成検証）。
  testWidgets('画面表示はサービス出力と一致する（合成の不変条件）', (tester) async {
    final books = [_finished('1'), _finished('2'), _finished('3')];
    final reviews = [_review('r1')];
    final sessions = [
      _session('s1', DateTime(2026, 10, 17, 9)),
      _session('s2', DateTime(2026, 10, 16, 9)),
      _session('s3', DateTime(2026, 10, 15, 9)),
    ];
    final source = _FakeSource(
      books: books,
      reviews: reviews,
      sessions: sessions,
    );
    final expected = const AchievementBadgeService().build(
      books: books,
      reviews: reviews,
      sessions: sessions,
      now: _now,
    );

    await _pump(tester, source);

    final summary = tester.widget<Text>(find.byKey(AppKeys.badgeSummaryLabel));
    expect(summary.data, contains(expected.summaryLabel));

    var visibleRows = 0;
    for (final progress in expected.progresses) {
      if (find.byKey(AppKeys.badgeRow(progress.definition.id)).evaluate().isNotEmpty) {
        visibleRows++;
      }
    }
    expect(visibleRows, expected.totalCount);
  });

  // 探針2: 獲得済み絞込は「獲得済みのみ」を表示し、未獲得を混入させない。
  testWidgets('獲得済み絞込は earned 集合と一致する', (tester) async {
    final books = [_finished('1'), _finished('2')];
    final reviews = [_review('r1')];
    final source = _FakeSource(books: books, reviews: reviews);
    final expected = const AchievementBadgeService().build(
      books: books,
      reviews: reviews,
      sessions: const [],
      now: _now,
    );

    await _pump(tester, source);
    await tester.tap(find.byKey(AppKeys.badgeFilterEarned));
    await tester.pumpAndSettle();

    for (final progress in expected.progresses) {
      final finder = find.byKey(AppKeys.badgeRow(progress.definition.id));
      if (progress.isEarned) {
        expect(finder, findsOneWidget,
            reason: '獲得済み ${progress.definition.id} が表示されない');
      } else {
        expect(finder, findsNothing,
            reason: '未獲得 ${progress.definition.id} が混入している');
      }
    }
  });

  // 探針3: 未獲得行にのみロックアイコンが付く（獲得行にロックが出ない）。
  testWidgets('未獲得行にのみロックアイコンが付く', (tester) async {
    final books = [_finished('1')];
    final source = _FakeSource(books: books);
    final expected = const AchievementBadgeService().build(
      books: books,
      reviews: const [],
      sessions: const [],
      now: _now,
    );

    await _pump(tester, source);

    for (final progress in expected.progresses) {
      final row = find.byKey(AppKeys.badgeRow(progress.definition.id));
      if (row.evaluate().isEmpty) continue;
      final lock = find.descendant(of: row, matching: find.byIcon(Icons.lock));
      if (progress.isEarned) {
        expect(lock, findsNothing,
            reason: '獲得済み ${progress.definition.id} にロックが出ている');
      } else {
        expect(lock, findsOneWidget,
            reason: '未獲得 ${progress.definition.id} にロックが無い');
      }
    }
  });

  // 探針4: 今日セッションが無くても昨日まで連続していれば連続日数を保つ
  // （画面→サービス→表示の合成で streak の意味論を撃つ）。
  testWidgets('今日未読でも昨日まで連続なら継続日数を保つ', (tester) async {
    final sessions = [
      _session('s1', DateTime(2026, 10, 16, 9)),
      _session('s2', DateTime(2026, 10, 15, 9)),
    ];
    final source = _FakeSource(sessions: sessions);

    await _pump(tester, source);

    final row = find.byKey(AppKeys.badgeRow('streak_3'));
    expect(row, findsOneWidget);
    final label = find.descendant(of: row, matching: find.textContaining('2 / 3'));
    expect(label, findsOneWidget);
  });

  // 探針5: 読書時間の合計が閾値に達したら当該バッジが獲得済みになる。
  testWidgets('読書時間の合計が閾値到達で獲得済みになる', (tester) async {
    final sessions = [
      _session('s1', DateTime(2026, 10, 17, 9), minutes: 400),
      _session('s2', DateTime(2026, 10, 16, 9), minutes: 250),
    ];
    final source = _FakeSource(sessions: sessions);

    await _pump(tester, source);

    final row = find.byKey(AppKeys.badgeRow('time_600'));
    expect(row, findsOneWidget);
    final lock = find.descendant(of: row, matching: find.byIcon(Icons.lock));
    expect(lock, findsNothing);
  });
}
