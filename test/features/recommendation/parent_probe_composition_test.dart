import 'dart:io';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/recommendation/presentation/recommendation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// 親探針（合成の不変条件）。
///
/// 子の試練は画面単体と導線単体を撃つが、『本棚の実データが導線を経て
/// 推薦画面の候補・嗜好に合成されるか』は誰も撃たない。ここで撃つ。
void main() {
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recommendation_probe');
    Hive.init(tempDir.path);
    repository = HiveBookRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await repository.close();
    try {
      await Hive.deleteBoxFromDisk('books');
    } catch (_) {}
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Book book({
    required String id,
    required String title,
    required String author,
    ReadingStatus status = ReadingStatus.unread,
    List<String> genres = const [],
  }) =>
      Book(
        id: id,
        title: title,
        author: author,
        isbn: 'isbn-$id',
        genres: genres,
        readingStatus: status,
      );

  testWidgets('合成: 本棚の読了本が嗜好を作り、導線経由で積読本が推薦される', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: BookshelfScreen(
        repository: repository,
        initialBooks: [
          // 読了本が嗜好（ジャンル: ミステリ）を形成する。
          book(
            id: 'finished-1',
            title: '読了済ミステリ',
            author: '好みの著者',
            status: ReadingStatus.finished,
            genres: ['ミステリ'],
          ),
          // 積読の候補。嗜好と一致するので推薦される。
          book(
            id: 'tsundoku-1',
            title: '積読ミステリ',
            author: '別人',
            genres: ['ミステリ'],
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('recommendation_button')));
    await tester.pumpAndSettle();

    // 積読本が推薦カードとして現れる（bookshelf→screen→service の合成）。
    expect(find.byKey(AppKeys.recommendationCard('tsundoku-1')), findsOneWidget);
    // 読了本は候補外。
    expect(find.byKey(AppKeys.recommendationCard('finished-1')), findsNothing);
    // 嗜好由来の推薦理由が合成後も表示される。
    expect(find.textContaining('好きなジャンル「ミステリ」'), findsWidgets);
  });

  testWidgets('合成: 候補ゼロ（全読了）なら本棚の導線から空状態に至る', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: BookshelfScreen(
        repository: repository,
        initialBooks: [
          book(
            id: 'f-1',
            title: '読了A',
            author: '著者',
            status: ReadingStatus.finished,
            genres: ['ミステリ'],
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('recommendation_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.recommendationEmpty), findsOneWidget);
  });

  testWidgets('limit が画面からサービスへ届く（limit=1で1件のみ）', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RecommendationScreen(
        books: [
          book(id: 'a', title: 'あ', author: 'x', genres: ['SF']),
          book(id: 'b', title: 'い', author: 'y', genres: ['SF']),
          book(id: 'c', title: 'う', author: 'z', genres: ['SF']),
        ],
        reviews: const [],
        limit: 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.recommendationCard('a')), findsOneWidget);
    expect(find.byKey(AppKeys.recommendationCard('b')), findsNothing);
    expect(find.byKey(AppKeys.recommendationCard('c')), findsNothing);
  });

  testWidgets('合成: ジャンル一致の候補には matchedGenres の Chip が出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RecommendationScreen(
        books: [
          book(
            id: 'fin',
            title: '読了',
            author: '著者',
            status: ReadingStatus.finished,
            genres: ['ミステリ'],
          ),
          book(id: 'cand', title: '候補', author: '著者', genres: ['ミステリ']),
        ],
        reviews: const [],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.recommendationCard('cand')), findsOneWidget);
    expect(find.text('ミステリ'), findsWidgets);
  });
}
