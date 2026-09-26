import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'dart:io';

/// 親探針: 「画面 → LibraryQuery → 絞り込み」の合成不変条件を撃つ。
/// 眷属の個別試練（Service 単体・チップ単体）が撃たない合成をここで確かめる。
class MockReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => [];

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

Book _book(String id, String title, List<String> genres) => Book(
      id: id,
      title: title,
      author: '著者',
      isbn: 'isbn-$id',
      genres: genres,
    );

Widget _buildApp(HiveBookRepository repository, List<Book> initialBooks) {
  return MaterialApp(
    home: BookshelfScreen(
      repository: repository,
      initialBooks: initialBooks,
      reviewRepository: MockReviewRepository(),
    ),
  );
}

void main() {
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_genre_probe_');
    Hive.init(tempDir.path);
    repository = HiveBookRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await repository.close();
    await Hive.deleteBoxFromDisk('books');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  final books = [
    _book('g1', '小説の本', ['小説']),
    _book('g2', '技術書の本', ['技術書']),
    _book('g3', '小説と技術書の本', ['小説', '技術書']),
    _book('g4', 'ジャンル無しの本', const []),
  ];

  testWidgets('蔵書のジャンルが件数付きチップとして本棚に現れる（画面→集計の合成）',
      (tester) async {
    await tester.pumpWidget(_buildApp(repository, books));
    await tester.pump();

    expect(find.byKey(AppKeys.genreFilterChip('小説')), findsOneWidget);
    expect(find.byKey(AppKeys.genreFilterChip('技術書')), findsOneWidget);
    // 件数が本棚の実データと一致する（小説2・技術書2）
    expect(find.text('小説 (2)'), findsOneWidget);
    expect(find.text('技術書 (2)'), findsOneWidget);
  });

  testWidgets('ジャンルチップの選択が一覧の絞り込みに本当に効く（画面→applyの合成）',
      (tester) async {
    await tester.pumpWidget(_buildApp(repository, books));
    await tester.pump();
    expect(find.text('ジャンル無しの本'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.genreFilterChip('技術書')));
    await tester.pumpAndSettle();

    expect(find.text('技術書の本'), findsOneWidget);
    expect(find.text('小説と技術書の本'), findsOneWidget);
    // ジャンルを持たない本は落ちる
    expect(find.text('小説の本'), findsNothing);
    expect(find.text('ジャンル無しの本'), findsNothing);
    // 件数表示も絞り込み後の件数と一致する
    final countText = tester
        .widget<Text>(find.byKey(const Key('library_count_text')))
        .data;
    expect(countText, '2 / 4 冊');
  });

  testWidgets('検索語とジャンルの AND 合成が効き、リセットで全件に戻る',
      (tester) async {
    await tester.pumpWidget(_buildApp(repository, books));
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.genreFilterChip('小説')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('library_search_field')), '技術書');
    await tester.pumpAndSettle();

    // 小説 かつ タイトルに「技術書」を含む本は1件のみ
    expect(find.text('小説と技術書の本'), findsOneWidget);
    expect(find.text('小説の本'), findsNothing);
    expect(find.text('技術書の本'), findsNothing);

    await tester.tap(find.byKey(const Key('library_reset_button')));
    await tester.pumpAndSettle();
    expect(find.text('小説の本'), findsOneWidget);
    expect(find.text('ジャンル無しの本'), findsOneWidget);
  });

  testWidgets('ジャンルを持つ蔵書が無ければチップ列は現れない', (tester) async {
    await tester.pumpWidget(_buildApp(repository, [
      _book('n1', '分類前の本', const []),
    ]));
    await tester.pump();

    expect(find.byKey(const Key('library_genre_chip_list')), findsNothing);
    expect(find.text('分類前の本'), findsOneWidget);
  });
}
