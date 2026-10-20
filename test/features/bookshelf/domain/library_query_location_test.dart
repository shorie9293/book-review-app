import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';

Book book({
  required String id,
  String title = 'タイトル',
  String author = '著者',
  List<String> genres = const [],
  String? location,
  ReadingStatus status = ReadingStatus.unread,
}) =>
    Book(
      id: id,
      title: title,
      author: author,
      isbn: 'isbn-$id',
      genres: genres,
      location: location,
      readingStatus: status,
    );

void main() {
  final books = <Book>[
    book(id: '1', title: 'Flutter入門', location: '居間の本棚', genres: ['技術書']),
    book(id: '2', title: 'Dart入門', location: '書斎の棚', genres: ['技術書']),
    book(id: '3', title: '小説A', location: '居間の本棚', genres: ['小説']),
    book(id: '4', title: '所在なし', genres: ['小説']),
  ];

  List<String> idsOf(List<Book> list) => list.map((b) => b.id).toList();

  group('locations 単独絞り込み', () {
    test('指定所在の本だけに絞る', () {
      final result = LibraryQueryService.apply(
        books,
        const LibraryQuery(locations: {'居間の本棚'}),
      );
      expect(idsOf(result), ['1', '3']);
    });

    test('複数所在は OR で絞る', () {
      final result = LibraryQueryService.apply(
        books,
        const LibraryQuery(locations: {'居間の本棚', '書斎の棚'}),
      );
      expect(idsOf(result), containsAll(['1', '2', '3']));
      expect(idsOf(result), hasLength(3));
    });

    test('空の locations は絞り込まない', () {
      final result = LibraryQueryService.apply(books, const LibraryQuery());
      expect(idsOf(result), hasLength(4));
    });

    test('所在未設定の本は一致しない', () {
      final result = LibraryQueryService.apply(
        books,
        const LibraryQuery(locations: {'書斎の棚'}),
      );
      expect(idsOf(result), ['2']);
    });

    test('正規化済みの所在で一致する（全角スペース入り）', () {
      final result = LibraryQueryService.apply(
        books,
        const LibraryQuery(locations: {'居間の本棚　'}),
      );
      expect(idsOf(result), ['1', '3']);
    });
  });

  group('他の条件との AND', () {
    test('テキストと locations の AND', () {
      final result = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: '入門', locations: {'居間の本棚'}),
      );
      expect(idsOf(result), ['1']);
    });

    test('ジャンルと locations の AND', () {
      final result = LibraryQueryService.apply(
        books,
        const LibraryQuery(genres: {'小説'}, locations: {'居間の本棚'}),
      );
      expect(idsOf(result), ['3']);
    });

    test('テキスト・ジャンル・locations の AND', () {
      final result = LibraryQueryService.apply(
        books,
        const LibraryQuery(
          text: '入門',
          genres: {'技術書'},
          locations: {'書斎の棚'},
        ),
      );
      expect(idsOf(result), ['2']);
    });
  });

  group('isDefault / activeFilterCount', () {
    test('locations のみの指定は既定ではない', () {
      const query = LibraryQuery(locations: {'居間の本棚'});
      expect(query.isDefault, isFalse);
      expect(query.activeFilterCount, 1);
    });

    test('locations が空なら既定のまま', () {
      const query = LibraryQuery();
      expect(query.isDefault, isTrue);
      expect(query.activeFilterCount, 0);
    });

    test('ジャンルと locations はそれぞれ1として数える', () {
      const query = LibraryQuery(genres: {'小説'}, locations: {'居間の本棚'});
      expect(query.activeFilterCount, 2);
    });

    test('テキスト・状態・ジャンル・所在・ソートの合算', () {
      const query = LibraryQuery(
        text: 'abc',
        statuses: {ReadingStatus.unread, ReadingStatus.reading},
        genres: {'小説'},
        locations: {'居間の本棚'},
        sortOrder: LibrarySortOrder.titleAsc,
      );
      expect(query.activeFilterCount, 6);
    });
  });

  group('copyWith', () {
    test('locations を差し替えられる', () {
      const query = LibraryQuery();
      final next = query.copyWith(locations: {'書斎の棚'});
      expect(next.locations, {'書斎の棚'});
      expect(query.locations, isEmpty);
    });

    test('clearLocations で空になる', () {
      const query = LibraryQuery(locations: {'書斎の棚'});
      final next = query.copyWith(clearLocations: true);
      expect(next.locations, isEmpty);
      expect(next.isDefault, isTrue);
    });

    test('他の条件は保持される', () {
      const query = LibraryQuery(
        text: 'abc',
        genres: {'小説'},
        locations: {'書斎の棚'},
      );
      final next = query.copyWith(locations: {'居間の本棚'});
      expect(next.text, 'abc');
      expect(next.genres, {'小説'});
      expect(next.locations, {'居間の本棚'});
    });
  });

  test('apply は入力リストと元の Book を破壊しない', () {
    final input = [
      book(id: '1', location: '居間の本棚'),
      book(id: '2'),
    ];
    final snapshot = [...input];
    LibraryQueryService.apply(
      input,
      const LibraryQuery(locations: {'居間の本棚'}),
    );
    expect(input, snapshot);
    expect(input.first.location, '居間の本棚');
    expect(input[1].location, isNull);
  });
}
