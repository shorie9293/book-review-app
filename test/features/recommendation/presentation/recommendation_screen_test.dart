import 'dart:io';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/recommendation/presentation/recommendation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Book _book({
  required String id,
  required String title,
  String author = '著者A',
  List<String> genres = const [],
  ReadingStatus status = ReadingStatus.unread,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    isbn: 'isbn-$id',
    genres: genres,
    readingStatus: status,
  );
}

Review _review({required String id, required String bookId, required int rating}) {
  final now = DateTime(2026, 1, 1);
  return Review(id: id, bookId: bookId, rating: rating, text: '', createdAt: now);
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  group('RecommendationScreen（直接注入）', () {
    testWidgets('画面ScaffoldにKeyが付与される', (tester) async {
      await _pump(
        tester,
        const RecommendationScreen(books: [], reviews: []),
      );
      expect(find.byKey(AppKeys.recommendationScreen), findsOneWidget);
    });

    testWidgets('AppBarに推薦タイトルが表示される', (tester) async {
      await _pump(
        tester,
        const RecommendationScreen(books: [], reviews: []),
      );
      expect(find.text('読書の推薦'), findsWidgets);
    });

    testWidgets('推薦件数分のカードが表示される', (tester) async {
      final books = [
        _book(id: 'b1', title: '積読1'),
        _book(id: 'b2', title: '積読2'),
        _book(id: 'b3', title: '積読3'),
      ];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: const []),
      );
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsOneWidget);
      expect(find.byKey(AppKeys.recommendationCard('b2')), findsOneWidget);
      expect(find.byKey(AppKeys.recommendationCard('b3')), findsOneWidget);
    });

    testWidgets('読了本はカードに出ない', (tester) async {
      final books = [
        _book(id: 'read1', title: '読了本', status: ReadingStatus.finished),
        _book(id: 'b1', title: '積読本'),
      ];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: const []),
      );
      expect(find.byKey(AppKeys.recommendationCard('read1')), findsNothing);
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsOneWidget);
    });

    testWidgets('カードにタイトルと著者が表示される', (tester) async {
      final books = [_book(id: 'b1', title: '吾輩は猫である', author: '夏目漱石')];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: const []),
      );
      expect(find.text('吾輩は猫である'), findsOneWidget);
      expect(find.text('夏目漱石'), findsOneWidget);
    });

    testWidgets('reason（推薦理由）が表示される', (tester) async {
      final books = [
        _book(id: 'b1', title: '積読本', author: '書き手X', genres: const ['SF']),
        _book(
          id: 'fin',
          title: '読了本',
          author: '書き手Y',
          genres: const ['SF'],
          status: ReadingStatus.finished,
        ),
      ];
      final reviews = [_review(id: 'r1', bookId: 'fin', rating: 5)];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: reviews),
      );
      expect(find.textContaining('好きなジャンル'), findsOneWidget);
    });

    testWidgets('matchedGenresがあるとChipが表示される', (tester) async {
      final books = [
        _book(id: 'b1', title: '積読本', genres: const ['SF']),
        _book(
          id: 'fin',
          title: '読了本',
          genres: const ['SF'],
          status: ReadingStatus.finished,
        ),
      ];
      final reviews = [_review(id: 'r1', bookId: 'fin', rating: 5)];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: reviews),
      );
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('SF'), findsOneWidget);
    });

    testWidgets('matchedGenresが空ならChip列を出さない', (tester) async {
      final books = [_book(id: 'b1', title: '積読本')];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: const []),
      );
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('scoreバッジにスコアが表示される', (tester) async {
      final books = [
        _book(id: 'b1', title: '積読本', author: '書き手X', genres: const ['SF']),
        _book(
          id: 'fin',
          title: '読了本',
          author: '書き手Y',
          genres: const ['SF'],
          status: ReadingStatus.finished,
        ),
      ];
      final reviews = [_review(id: 'r1', bookId: 'fin', rating: 5)];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: reviews),
      );
      // genre一致で score=3
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('候補ゼロで空状態Keyが表示される', (tester) async {
      await _pump(
        tester,
        const RecommendationScreen(books: [], reviews: []),
      );
      expect(find.byKey(AppKeys.recommendationEmpty), findsOneWidget);
      expect(find.textContaining('推薦できる積読'), findsOneWidget);
    });

    testWidgets('候補ゼロではカードが出ない', (tester) async {
      await _pump(
        tester,
        const RecommendationScreen(books: [], reviews: []),
      );
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('全て読了済みなら空状態になる', (tester) async {
      final books = [
        _book(id: 'f1', title: '読了A', status: ReadingStatus.finished),
      ];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: const []),
      );
      expect(find.byKey(AppKeys.recommendationEmpty), findsOneWidget);
    });

    testWidgets('limit=0で空状態になる', (tester) async {
      final books = [
        _book(id: 'b1', title: '積読1'),
        _book(id: 'b2', title: '積読2'),
      ];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: const [], limit: 0),
      );
      expect(find.byKey(AppKeys.recommendationEmpty), findsOneWidget);
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsNothing);
    });

    testWidgets('limitで表示件数が切り詰められる', (tester) async {
      final books = [
        _book(id: 'b1', title: '積読1'),
        _book(id: 'b2', title: '積読2'),
        _book(id: 'b3', title: '積読3'),
      ];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: const [], limit: 2),
      );
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsOneWidget);
      expect(find.byKey(AppKeys.recommendationCard('b2')), findsOneWidget);
      expect(find.byKey(AppKeys.recommendationCard('b3')), findsNothing);
    });

    testWidgets('先頭カードが最高スコアの推薦である', (tester) async {
      // 読了: SF+ミステリ。候補b1は両方一致(6)、b2はSFのみ(3)。
      final books = [
        _book(id: 'b2', title: 'B曲線', genres: const ['SF']),
        _book(id: 'b1', title: 'A理論', genres: const ['SF', 'ミステリ']),
        _book(
          id: 'fin',
          title: '読了本',
          genres: const ['SF', 'ミステリ'],
          status: ReadingStatus.finished,
        ),
      ];
      final reviews = [_review(id: 'r1', bookId: 'fin', rating: 5)];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: reviews),
      );
      // ListViewの先頭要素は b1（スコア6）
      final listViews = find.byType(ListView);
      expect(listViews, findsOneWidget);
      final firstCardText =
          tester.widget<ListView>(listViews.first).childrenDelegate;
      // childrenDelegate の直接検証は困難なため、描画済み順序で検証
      final b1Finder = find.byKey(AppKeys.recommendationCard('b1'));
      final b2Finder = find.byKey(AppKeys.recommendationCard('b2'));
      expect(b1Finder, findsOneWidget);
      expect(b2Finder, findsOneWidget);
      expect(
        tester.getTopLeft(b1Finder).dy,
        lessThan(tester.getTopLeft(b2Finder).dy),
      );
      expect(firstCardText, isNotNull);
    });

    testWidgets('高評価レビューの著者の本が上位に出る', (tester) async {
      // author一致は+5、genreなしでもscore>0になり上位
      final books = [
        _book(id: 'b1', title: '同著者新作', author: '人気作家'),
        _book(id: 'b2', title: '別著者本', author: '別人'),
        _book(
          id: 'fin',
          title: '読了本',
          author: '人気作家',
          status: ReadingStatus.finished,
        ),
      ];
      final reviews = [_review(id: 'r1', bookId: 'fin', rating: 5)];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: reviews),
      );
      final b1 = find.byKey(AppKeys.recommendationCard('b1'));
      final b2 = find.byKey(AppKeys.recommendationCard('b2'));
      expect(
        tester.getTopLeft(b1).dy,
        lessThan(tester.getTopLeft(b2).dy),
      );
    });

    testWidgets('低評価レビューのみでは嗜好に反映されない（chipゼロ）', (tester) async {
      final books = [
        _book(id: 'b1', title: '積読本', genres: const ['SF']),
        _book(
          id: 'fin',
          title: '読了本',
          genres: const ['歴史'],
          status: ReadingStatus.finished,
        ),
      ];
      final reviews = [_review(id: 'r1', bookId: 'fin', rating: 2)];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: reviews),
      );
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('読書中の本も候補になる', (tester) async {
      final books = [
        _book(id: 'b1', title: '読書中本', status: ReadingStatus.reading),
      ];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: const []),
      );
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsOneWidget);
    });

    testWidgets('著者一致でreasonに著者名が出る', (tester) async {
      final books = [
        _book(id: 'b1', title: '同著者新作', author: '人気作家'),
        _book(
          id: 'fin',
          title: '読了本',
          author: '人気作家',
          status: ReadingStatus.finished,
        ),
      ];
      final reviews = [_review(id: 'r1', bookId: 'fin', rating: 5)];
      await _pump(
        tester,
        RecommendationScreen(books: books, reviews: reviews),
      );
      expect(find.textContaining('好きな著者'), findsOneWidget);
    });
  });

  group('books注入時の非ブロッキング描画', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recommendation_bg');
      Hive.init(tempDir.path);
      // 事前にboxを開いておく（未初期化HiveのopenBoxはリスナー無しcompleterに
      // completeErrorするため、try/catchで握っても試練フレームワークに漏れる）。
      await HiveBookRepository().init();
      await HiveChallengeRepository().init();
    });

    tearDown(() async {
      await Hive.close();
      await Hive.deleteBoxFromDisk('books');
      await Hive.deleteBoxFromDisk('reviews');
      await Hive.deleteBoxFromDisk('challenge');
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('books注入・reviews未指定でも即描画する（スピナーを出さない）', (tester) async {
      final books = [
        _book(id: 'b1', title: '積読本'),
        _book(id: 'b2', title: '積読2'),
      ];
      // reviewsは背景取得され、描画をブロックしない。
      await _pump(tester, RecommendationScreen(books: books));
      expect(find.byKey(AppKeys.recommendationLoading), findsNothing);
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsOneWidget);
      expect(find.byKey(AppKeys.recommendationCard('b2')), findsOneWidget);
    });

    testWidgets('books注入時はpumpAndSettleがタイムアウトしない（回帰防止）', (tester) async {
      final books = [_book(id: 'b1', title: '積読本')];
      // 旧実装では reviews 未注入でローディングに入りタイムアウトしていた。
      await _pump(tester, RecommendationScreen(books: books));
      expect(find.byKey(AppKeys.recommendationLoading), findsNothing);
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsOneWidget);
    });

    testWidgets('books未注入・reviews注入でも即描画する', (tester) async {
      final reviews = [_review(id: 'r1', bookId: 'b1', rating: 5)];
      // booksのみ背景取得される。箱は空なので空状態（既存の意味論どおり）。
      await _pump(tester, RecommendationScreen(reviews: reviews));
      expect(find.byKey(AppKeys.recommendationLoading), findsNothing);
      expect(find.byKey(AppKeys.recommendationEmpty), findsOneWidget);
    });
  });

  group('本棚からの導線', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recommendation_wiring');
      Hive.init(tempDir.path);
      // 事前にboxを開いておく（openBoxは既に開いているboxを即返すため
      // fake async 内の Hive I/O で pumpAndSettle が滞留しない）
      await HiveBookRepository().init();
      await HiveChallengeRepository().init();
    });

    tearDown(() async {
      await Hive.close();
      await Hive.deleteBoxFromDisk('books');
      await Hive.deleteBoxFromDisk('reviews');
      await Hive.deleteBoxFromDisk('challenge');
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('recommendation_buttonをタップすると推薦画面へ遷移する', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: BookshelfScreen(
          repository: _StubRepository(),
          initialBooks: [
            _book(id: 'b1', title: '積読本'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recommendation_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.recommendationScreen), findsOneWidget);
      expect(find.text('読書の推薦'), findsWidgets);
      // 本棚から渡された本が推薦カードとして出る
      expect(find.byKey(AppKeys.recommendationCard('b1')), findsOneWidget);
    });
  });
}

class _StubRepository implements BookRepository {
  @override
  Future<List<Book>> getBooks() async => const [];

  @override
  Future<Book?> getBookById(String id) async => null;

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async {}

  @override
  Future<void> updateBook(Book book) async {}

  @override
  Future<void> removeBook(String id) async {}
}
