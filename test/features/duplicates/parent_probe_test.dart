import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/duplicates/domain/duplicate_book_service.dart';
import 'package:book_review_app/features/duplicates/presentation/duplicate_books_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';

/// 親探針（合成の不変条件）。
///
/// 眷属は個別操作しか撃たないため、親が
/// 「画面 → リポジトリ永続化」「代表選択の貫通」「関連データの移行」
/// を自分の手で撃って実バグが無いことを確かめる。
Book mkBook({
  required String id,
  required String title,
  required String isbn,
  DateTime? addedAt,
  ReadingStatus status = ReadingStatus.unread,
  int currentPage = 0,
  List<String> genres = const [],
  String? location,
  String? description,
}) =>
    Book(
      id: id,
      title: title,
      author: '著者',
      isbn: isbn,
      addedAt: addedAt,
      readingStatus: status,
      currentPage: currentPage,
      genres: genres,
      location: location,
      description: description,
    );

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    DuplicateBooksScreen screen,
  ) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> confirmDialog(WidgetTester tester) async {
    await tester.tap(find.text('統合する'));
    await tester.pumpAndSettle();
  }

  testWidgets('統合はリポジトリへ到達し、代表以外は実際に削除される（3冊組）',
      (tester) async {
    final books = [
      mkBook(
        id: 'b1',
        title: '重複本',
        isbn: '978-4-06-519123-4',
        addedAt: DateTime(2026, 1, 1),
        status: ReadingStatus.unread,
        currentPage: 10,
        genres: const ['小説'],
      ),
      mkBook(
        id: 'b2',
        title: '重複本',
        isbn: '9784065191234',
        addedAt: DateTime(2026, 2, 1),
        status: ReadingStatus.finished,
        currentPage: 320,
        genres: const ['エッセイ'],
        location: '居間の本棚 2段目',
      ),
      mkBook(
        id: 'b3',
        title: '重複本',
        isbn: '978 4 06 519123 4',
        addedAt: DateTime(2026, 3, 1),
        status: ReadingStatus.reading,
        currentPage: 40,
        description: '最も長い説明文がここに入る',
      ),
    ];
    final repository = FakeBookRepository(books);
    await pumpScreen(
      tester,
      DuplicateBooksScreen(repository: repository),
    );

    expect(find.byKey(AppKeys.duplicateGroupCard('9784065191234')),
        findsOneWidget);
    expect(find.text('3冊'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.duplicateMergeButton('9784065191234')));
    await tester.pumpAndSettle();
    await confirmDialog(tester);

    // リポジトリへ永続化されている（state 更新だけで終わっていない）。
    expect(repository.bookIds, ['b1']);
    final merged = repository.books.single;
    expect(merged.id, 'b1');
    expect(merged.genres, containsAll(<String>['小説', 'エッセイ']));
    expect(merged.currentPage, 320);
    expect(merged.readingStatus, ReadingStatus.finished);
    expect(merged.location, '居間の本棚 2段目');
    expect(merged.description, '最も長い説明文がここに入る');
    // 追加日時は最も早いもの
    expect(merged.addedAt, DateTime(2026, 1, 1));
    // 画面からも組が消える
    expect(find.byKey(AppKeys.duplicateGroupCard('9784065191234')),
        findsNothing);
    expect(find.byKey(AppKeys.duplicateEmpty), findsOneWidget);
  });

  testWidgets('統合時にメモ・レビューが代表蔵書へ移行される', (tester) async {
    final books = [
      mkBook(id: 'k', title: '本', isbn: '1111111111'),
      mkBook(id: 'x', title: '本', isbn: '111-111-1111'),
    ];
    final repository = FakeBookRepository(books);
    final noteRepository = FakeNoteRepository([
      BookNote(
        id: 'n1',
        bookId: 'x',
        kind: NoteKind.memo,
        content: '消えないでほしいメモ',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);
    final reviewRepository = FakeReviewRepository([
      Review(
        id: 'r1',
        bookId: 'x',
        rating: 4,
        text: '良い本',
        createdAt: DateTime(2026, 1, 2),
      ),
    ]);
    await pumpScreen(
      tester,
      DuplicateBooksScreen(
        repository: repository,
        noteRepository: noteRepository,
        reviewRepository: reviewRepository,
      ),
    );

    await tester.tap(find.byKey(AppKeys.duplicateMergeButton('1111111111')));
    await tester.pumpAndSettle();
    await confirmDialog(tester);

    expect(repository.bookIds, ['k']);
    expect(noteRepository.notes, hasLength(1));
    expect(noteRepository.notes.single.id, 'n1');
    expect(noteRepository.notes.single.bookId, 'k');
    expect(reviewRepository.reviews, hasLength(1));
    expect(reviewRepository.reviews.single.id, 'r1');
    expect(reviewRepository.reviews.single.bookId, 'k');
  });

  testWidgets('代表を切り替えると選んだ側の蔵書が残る', (tester) async {
    final books = [
      mkBook(
        id: 'first',
        title: '古い登録',
        isbn: '2222222222',
        addedAt: DateTime(2026, 1, 1),
      ),
      mkBook(
        id: 'second',
        title: '新しい登録',
        isbn: '222-222-2222',
        addedAt: DateTime(2026, 5, 1),
        status: ReadingStatus.reading,
        currentPage: 77,
      ),
    ];
    final repository = FakeBookRepository(books);
    await pumpScreen(
      tester,
      DuplicateBooksScreen(repository: repository),
    );

    await tester.tap(find.byKey(AppKeys.duplicateKeepRadio('second')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.duplicateMergeButton('2222222222')));
    await tester.pumpAndSettle();
    await confirmDialog(tester);

    expect(repository.bookIds, ['second']);
    expect(repository.books.single.currentPage, 77);
  });

  testWidgets('統合計画と画面の結果が一致する（サービス出力を正とする）',
      (tester) async {
    final books = [
      mkBook(id: 'p', title: 'A', isbn: '3333333333'),
      mkBook(id: 'q', title: 'B', isbn: '333-333-3333'),
    ];
    final expected =
        DuplicateBookService.planMerge(DuplicateBookService.findGroups(books).single, 'p');
    final repository = FakeBookRepository(books);
    await pumpScreen(
      tester,
      DuplicateBooksScreen(repository: repository),
    );

    await tester.tap(find.byKey(AppKeys.duplicateMergeButton('3333333333')));
    await tester.pumpAndSettle();
    await confirmDialog(tester);

    final merged = repository.books.single;
    expect(merged.id, expected.merged.id);
    expect(merged.addedAt, expected.merged.addedAt);
    expect(merged.genres, expected.merged.genres);
    expect(merged.currentPage, expected.merged.currentPage);
  });

  testWidgets('個別削除は組の1冊だけを消し、残りは組として残る', (tester) async {
    final books = [
      mkBook(id: 'd1', title: '本', isbn: '4444444444'),
      mkBook(id: 'd2', title: '本', isbn: '444-444-4444'),
      mkBook(id: 'd3', title: '本', isbn: '444 444 4444'),
    ];
    final repository = FakeBookRepository(books);
    await pumpScreen(
      tester,
      DuplicateBooksScreen(repository: repository),
    );

    await tester.tap(find.byKey(AppKeys.duplicateDeleteButton('d3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(repository.bookIds, containsAll(<String>['d1', 'd2']));
    expect(repository.bookIds, isNot(contains('d3')));
    expect(find.text('2冊'), findsOneWidget);
  });
}
