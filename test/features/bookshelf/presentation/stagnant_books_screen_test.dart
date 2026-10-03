import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/presentation/stagnant_books_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book({
  required String id,
  String title = '本',
  ReadingStatus status = ReadingStatus.unread,
  int currentPage = 0,
  required int daysAgo,
}) {
  return Book(
    id: id,
    title: title,
    author: '著者$id',
    isbn: 'isbn-$id',
    readingStatus: status,
    currentPage: currentPage,
    addedAt: DateTime(2026, 10, 3).subtract(Duration(days: daysAgo)),
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<Book> books, {
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: StagnantBooksScreen(books: books, now: now ?? _fixedNow)),
  );
  await tester.pumpAndSettle();
}

final DateTime _fixedNow = DateTime(2026, 10, 3, 12);

void main() {
  testWidgets('停滞本の一覧と件数・経過日数を表示する', (tester) async {
    await _pump(tester, [
      _book(id: 'old', title: '古い本', daysAgo: 40),
      _book(id: 'fresh', title: '新しい本', daysAgo: 2),
    ]);
    expect(find.byKey(AppKeys.stagnantCountLabel), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantEntry('old')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantEntry('fresh')), findsNothing);
    final daysText =
        tester.widget<Text>(find.byKey(AppKeys.stagnantDays('old'))).data;
    expect(daysText, contains('40'));
  });

  testWidgets('読了の本は対象外・全件停滞なら空状態', (tester) async {
    await _pump(tester, [
      _book(
        id: 'done',
        status: ReadingStatus.finished,
        daysAgo: 100,
      ),
    ]);
    expect(find.byKey(AppKeys.stagnantEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantEntry('done')), findsNothing);
  });

  testWidgets('閾値チップ（7日）で対象が増える', (tester) async {
    await _pump(tester, [
      _book(id: 'w8', title: '8日前の本', daysAgo: 8),
      _book(id: 'w40', title: '40日前の本', daysAgo: 40),
    ]);
    expect(find.byKey(AppKeys.stagnantEntry('w8')), findsNothing);
    await tester.tap(find.byKey(AppKeys.stagnantMinChip(7)));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.stagnantEntry('w8')), findsOneWidget);
  });

  testWidgets('理由チップで絞り込める', (tester) async {
    await _pump(tester, [
      _book(id: 'u', title: '積読の本', daysAgo: 30),
      _book(
        id: 'r',
        title: '停滞中の本',
        status: ReadingStatus.reading,
        currentPage: 5,
        daysAgo: 30,
      ),
    ]);
    await tester.tap(find.byKey(AppKeys.stagnantReasonChip('neverStarted')));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.stagnantEntry('u')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantEntry('r')), findsNothing);
    // 絞込解除（同じチップを再タップ）
    await tester.tap(find.byKey(AppKeys.stagnantReasonChip('neverStarted')));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.stagnantEntry('r')), findsOneWidget);
  });

  testWidgets('検索欄で書名の部分一致に絞り込める', (tester) async {
    await _pump(tester, [
      _book(id: 'd1', title: 'ドラゴン教本', daysAgo: 30),
      _book(id: 'd2', title: '猫の飼い方', daysAgo: 30),
    ]);
    await tester.enterText(find.byKey(AppKeys.stagnantSearchField), 'ドラゴン');
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.stagnantEntry('d1')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantEntry('d2')), findsNothing);
    await tester.tap(find.byKey(AppKeys.stagnantSearchClear));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.stagnantEntry('d2')), findsOneWidget);
  });

  testWidgets('複数条件の合成: 検索×理由×閾値の件数が一致する', (tester) async {
    await _pump(tester, [
      _book(id: 'a', title: 'ドラゴンA', daysAgo: 8),
      _book(id: 'b', title: 'ドラゴンB', daysAgo: 30),
      _book(
        id: 'c',
        title: 'ドラゴンC',
        status: ReadingStatus.reading,
        currentPage: 3,
        daysAgo: 30,
      ),
    ]);
    await tester.enterText(find.byKey(AppKeys.stagnantSearchField), 'ドラゴン');
    await tester.tap(find.byKey(AppKeys.stagnantMinChip(7)));
    await tester.tap(find.byKey(AppKeys.stagnantReasonChip('neverStarted')));
    await tester.pumpAndSettle();
    // 検索(3件) × 7日以上(3件) × 未着手(a,b) = 2件
    expect(find.byKey(AppKeys.stagnantEntry('a')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantEntry('b')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantEntry('c')), findsNothing);
  });
}