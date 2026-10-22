import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/duplicates/presentation/duplicate_books_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

const String kIsbnKey = '9784065191234';

Book mk({
  required String id,
  required String title,
  String author = '著者',
  String isbn = '978-4-06-519123-4',
  ReadingStatus readingStatus = ReadingStatus.unread,
  int currentPage = 0,
  DateTime? addedAt,
}) =>
    Book(
      id: id,
      title: title,
      author: author,
      isbn: isbn,
      readingStatus: readingStatus,
      currentPage: currentPage,
      addedAt: addedAt,
    );

Widget buildScreen({
  required FakeBookRepository repository,
  List<Book>? booksOverride,
  FakeNoteRepository? noteRepository,
  FakeReviewRepository? reviewRepository,
}) =>
    MaterialApp(
      home: DuplicateBooksScreen(
        repository: repository,
        booksOverride: booksOverride,
        noteRepository: noteRepository,
        reviewRepository: reviewRepository,
      ),
    );

void main() {
  Future<void> pumpWithViewport(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  final group = [
    mk(
      id: 'a',
      title: '重複本A',
      readingStatus: ReadingStatus.reading,
      currentPage: 30,
      addedAt: DateTime.utc(2026, 1, 2),
    ),
    mk(
      id: 'b',
      title: '重複本B',
      readingStatus: ReadingStatus.unread,
      addedAt: DateTime.utc(2026, 2, 3),
    ),
    mk(id: 'c', title: '別の本', isbn: '9781234567890'),
  ];

  testWidgets('重複した組がサマリーとカードで表示される', (tester) async {
    final repository = FakeBookRepository(group);
    await pumpWithViewport(
      tester,
      buildScreen(repository: repository, booksOverride: group),
    );

    expect(find.text('重複した蔵書'), findsOneWidget);
    expect(find.text('重複した蔵書が 1組（2冊）あります'), findsOneWidget);
    expect(find.byKey(AppKeys.duplicateGroupCard(kIsbnKey)), findsOneWidget);
    expect(find.byKey(AppKeys.duplicateKeepRadio('a')), findsOneWidget);
    expect(find.byKey(AppKeys.duplicateKeepRadio('b')), findsOneWidget);
    expect(find.byKey(AppKeys.duplicateKeepRadio('c')), findsNothing);
    expect(find.text('2冊'), findsOneWidget);
    // 既定選択は代表（最も古く追加された a）。
    expect(find.text('追加: 2026/01/02 / 状態: 読書中 / 30ページ'), findsOneWidget);
  });

  testWidgets('重複が無い場合は空状態を表示する', (tester) async {
    final books = [
      mk(id: 'x', title: '本X', isbn: '9781111111111'),
      mk(id: 'y', title: '本Y', isbn: '9782222222222'),
    ];
    final repository = FakeBookRepository(books);
    await pumpWithViewport(
      tester,
      buildScreen(repository: repository, booksOverride: books),
    );

    expect(find.byKey(AppKeys.duplicateEmpty), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(AppKeys.duplicateEmpty),
        matching: find.text('重複した蔵書はありません'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('代表を変えて統合すると選択した側の id が残る', (tester) async {
    final repository = FakeBookRepository(group);
    await pumpWithViewport(
      tester,
      buildScreen(repository: repository, booksOverride: group),
    );

    await tester.tap(find.byKey(AppKeys.duplicateKeepRadio('b')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.duplicateMergeButton(kIsbnKey)));
    await tester.pumpAndSettle();
    expect(
      find.text('重複した 2 冊を1冊に統合します。よろしいですか？'),
      findsOneWidget,
    );

    await tester.tap(find.text('統合する'));
    await tester.pumpAndSettle();

    // 選択した b が残り、a は消えている。
    expect(find.byKey(AppKeys.duplicateKeepRadio('b')), findsNothing);
    expect(find.byKey(AppKeys.duplicateKeepRadio('a')), findsNothing);
    expect(find.byKey(AppKeys.duplicateGroupCard(kIsbnKey)), findsNothing);
    expect(find.byKey(AppKeys.duplicateEmpty), findsOneWidget);
    expect(repository.bookIds, containsAll(<String>['b', 'c']));
    expect(repository.bookIds, isNot(contains('a')));
    expect(find.text('1冊を1冊に統合しました'), findsOneWidget);
  });

  testWidgets('統合時にメモとレビューが代表へ移行する', (tester) async {
    final repository = FakeBookRepository(group);
    final noteRepository = FakeNoteRepository([
      BookNote(
        id: 'note-1',
        bookId: 'a',
        content: '気づき',
        createdAt: DateTime.utc(2026, 1, 3),
      ),
    ]);
    final reviewRepository = FakeReviewRepository([
      Review(
        id: 'review-1',
        bookId: 'a',
        rating: 4,
        text: '良い',
        createdAt: DateTime.utc(2026, 1, 4),
      ),
    ]);
    await pumpWithViewport(
      tester,
      buildScreen(
        repository: repository,
        booksOverride: group,
        noteRepository: noteRepository,
        reviewRepository: reviewRepository,
      ),
    );

    // 代表を b に切り替えて統合 → a 側のメモ・レビューが b へ移る。
    await tester.tap(find.byKey(AppKeys.duplicateKeepRadio('b')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.duplicateMergeButton(kIsbnKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('統合する'));
    await tester.pumpAndSettle();

    expect(noteRepository.notes, hasLength(1));
    expect(noteRepository.notes.single.id, 'note-1');
    expect(noteRepository.notes.single.bookId, 'b');
    expect(reviewRepository.reviews, hasLength(1));
    expect(reviewRepository.reviews.single.id, 'review-1');
    expect(reviewRepository.reviews.single.bookId, 'b');
  });

  testWidgets('個別削除ボタンで確認のうえ1冊を削除する', (tester) async {
    final books = [
      mk(id: 'a', title: '重複本A', addedAt: DateTime.utc(2026, 1, 2)),
      mk(id: 'b', title: '重複本B', addedAt: DateTime.utc(2026, 2, 3)),
      mk(id: 'd', title: '重複本D', addedAt: DateTime.utc(2026, 3, 4)),
    ];
    final repository = FakeBookRepository(books);
    await pumpWithViewport(
      tester,
      buildScreen(repository: repository, booksOverride: books),
    );

    expect(find.text('3冊'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.duplicateDeleteButton('a')));
    await tester.pumpAndSettle();
    expect(find.text('「重複本A」を削除します。よろしいですか？'), findsOneWidget);

    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(repository.bookIds, isNot(contains('a')));
    expect(find.byKey(AppKeys.duplicateKeepRadio('a')), findsNothing);
    expect(find.byKey(AppKeys.duplicateKeepRadio('b')), findsOneWidget);
    expect(find.byKey(AppKeys.duplicateKeepRadio('d')), findsOneWidget);
    expect(find.text('2冊'), findsOneWidget);
    expect(find.text('1冊を削除しました'), findsOneWidget);
  });

  testWidgets('リポジトリ例外はスナックバーで提示する', (tester) async {
    final repository = FakeBookRepository(group)..failOnUpdate = true;
    await pumpWithViewport(
      tester,
      buildScreen(repository: repository, booksOverride: group),
    );

    await tester.tap(find.byKey(AppKeys.duplicateMergeButton(kIsbnKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('統合する'));
    await tester.pumpAndSettle();

    expect(find.textContaining('統合に失敗しました'), findsOneWidget);
    expect(repository.bookIds, containsAll(<String>['a', 'b', 'c']));
  });
}
