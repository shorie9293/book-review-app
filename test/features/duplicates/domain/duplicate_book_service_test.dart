import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/duplicates/domain/duplicate_book_group.dart';
import 'package:book_review_app/features/duplicates/domain/duplicate_book_service.dart';
import 'package:flutter_test/flutter_test.dart';

Book mk({
  required String id,
  String title = 'T',
  String author = 'A',
  String isbn = '9784065191234',
  String? coverImageUrl,
  String? publisher,
  String? publishedDate,
  int? pageCount,
  String? description,
  List<String> genres = const [],
  String? location,
  ReadingStatus readingStatus = ReadingStatus.unread,
  int currentPage = 0,
  DateTime? finishedAt,
  DateTime? addedAt,
}) =>
    Book(
      id: id,
      title: title,
      author: author,
      isbn: isbn,
      coverImageUrl: coverImageUrl,
      publisher: publisher,
      publishedDate: publishedDate,
      pageCount: pageCount,
      description: description,
      genres: genres,
      location: location,
      readingStatus: readingStatus,
      currentPage: currentPage,
      finishedAt: finishedAt,
      addedAt: addedAt,
    );

DateTime dt(int day, [int hour = 0]) => DateTime.utc(2026, 1, day, hour);

void main() {
  // ---------------------------------------------------------------------------
  // normalizeIsbn
  // ---------------------------------------------------------------------------
  group('normalizeIsbn', () {
    test('スペースとハイフンを除去する', () {
      expect(DuplicateBookService.normalizeIsbn('978-4-06-519123-4'),
          '9784065191234');
      expect(DuplicateBookService.normalizeIsbn(' 978 4065 191234 '),
          '9784065191234');
    });

    test('各種ダッシュ・長音記号をすべて除去する', () {
      // '-', '‐'(U+2010), '–'(U+2013), '—'(U+2014), '−'(U+2212)
      expect(
        DuplicateBookService.normalizeIsbn('978\u20104065\u20131912\u20143\u22124'),
        '9784065191234',
      );
      expect(DuplicateBookService.normalizeIsbn('1-2\u20103\u20144\u22125'),
          '12345');
    });

    test('全角スペースを除去する', () {
      expect(DuplicateBookService.normalizeIsbn('97\u300084065191234'),
          '9784065191234');
    });

    test('trim して大文字化する', () {
      expect(DuplicateBookService.normalizeIsbn('  ab-12 '), 'AB12');
    });

    test('正規化後に空なら空文字を返す', () {
      expect(DuplicateBookService.normalizeIsbn(''), '');
      expect(DuplicateBookService.normalizeIsbn('   '), '');
      expect(DuplicateBookService.normalizeIsbn('\u3000\u3000'), '');
      expect(DuplicateBookService.normalizeIsbn('---\u2010\u2013\u2014\u2212'),
          '');
    });
  });

  // ---------------------------------------------------------------------------
  // DuplicateBookGroup
  // ---------------------------------------------------------------------------
  group('DuplicateBookGroup', () {
    test('count / representative / bookIds / countLabel', () {
      final b1 = mk(id: 'b1', addedAt: dt(1));
      final b2 = mk(id: 'b2', addedAt: dt(2));
      final group = DuplicateBookGroup(
        isbnKey: '9784065191234',
        books: [b1, b2],
      );

      expect(group.count, 2);
      expect(group.representative, same(b1));
      expect(group.bookIds, ['b1', 'b2']);
      expect(group.countLabel, '2冊');
    });
  });

  // ---------------------------------------------------------------------------
  // findGroups
  // ---------------------------------------------------------------------------
  group('findGroups', () {
    test('空リストでも例外を投げず空を返す', () {
      expect(DuplicateBookService.findGroups(const []), isEmpty);
    });

    test('1冊だけなら組にならない', () {
      expect(
        DuplicateBookService.findGroups([mk(id: 'b1', addedAt: dt(1))]),
        isEmpty,
      );
    });

    test('正規化後のISBNが同一なら組になる', () {
      final books = [
        mk(id: 'b1', isbn: '978-4-06-519123-4', addedAt: dt(1)),
        mk(id: 'b2', isbn: '9784065191234', addedAt: dt(2)),
      ];
      final groups = DuplicateBookService.findGroups(books);

      expect(groups, hasLength(1));
      expect(groups.single.isbnKey, '9784065191234');
      expect(groups.single.count, 2);
      expect(groups.single.bookIds, ['b1', 'b2']);
    });

    test('ISBNが正規化後に空の蔵書は組に入れない', () {
      final books = [
        mk(id: 'b1', isbn: '', addedAt: dt(1)),
        mk(id: 'b2', isbn: '   ', addedAt: dt(2)),
        mk(id: 'b3', isbn: '---', addedAt: dt(3)),
      ];
      expect(DuplicateBookService.findGroups(books), isEmpty);
    });

    test('空ISBNは非空ISBNの組に混入しない', () {
      final books = [
        mk(id: 'b1', isbn: '9784065191234', addedAt: dt(1)),
        mk(id: 'b2', isbn: '9784065191234', addedAt: dt(2)),
        mk(id: 'b3', isbn: '', addedAt: dt(3)),
      ];
      final groups = DuplicateBookService.findGroups(books);
      expect(groups.single.bookIds, ['b1', 'b2']);
    });

    test('組は count 降順 → isbnKey 昇順', () {
      final books = [
        // isbnKey '222' count 2
        mk(id: 'a1', isbn: '222', addedAt: dt(1)),
        mk(id: 'a2', isbn: '222', addedAt: dt(2)),
        // isbnKey '111' count 2
        mk(id: 'c1', isbn: '111', addedAt: dt(1)),
        mk(id: 'c2', isbn: '111', addedAt: dt(2)),
        // isbnKey '333' count 3
        mk(id: 'b1', isbn: '333', addedAt: dt(1)),
        mk(id: 'b2', isbn: '333', addedAt: dt(2)),
        mk(id: 'b3', isbn: '333', addedAt: dt(3)),
      ];
      final groups = DuplicateBookService.findGroups(books);

      expect(groups.map((g) => g.isbnKey).toList(), ['333', '111', '222']);
    });

    test('組内は addedAt 昇順（null は末尾）', () {
      final books = [
        mk(id: 'n1', addedAt: null),
        mk(id: 'l1', addedAt: dt(5)),
        mk(id: 'e1', addedAt: dt(2)),
      ];
      final groups = DuplicateBookService.findGroups(books);
      expect(groups.single.bookIds, ['e1', 'l1', 'n1']);
    });

    test('同時刻は id 昇順', () {
      final books = [
        mk(id: 'c', addedAt: dt(1)),
        mk(id: 'a', addedAt: dt(1)),
        mk(id: 'b', addedAt: dt(1)),
      ];
      final groups = DuplicateBookService.findGroups(books);
      expect(groups.single.bookIds, ['a', 'b', 'c']);
    });

    test('id も同時刻も同じなら元 index 順で安定する', () {
      final books = [
        mk(id: 'x', title: 'first', addedAt: null),
        mk(id: 'x', title: 'second', addedAt: null),
        mk(id: 'x', title: 'third', addedAt: null),
      ];
      final groups = DuplicateBookService.findGroups(books);
      expect(groups.single.books.map((b) => b.title).toList(),
          ['first', 'second', 'third']);
    });

    test('入力を破壊しない', () {
      final b1 = mk(id: 'b1', addedAt: dt(3));
      final b2 = mk(id: 'b2', addedAt: dt(1));
      final books = [b1, b2];
      DuplicateBookService.findGroups(books);

      expect(books, [same(b1), same(b2)]);
    });
  });

  // ---------------------------------------------------------------------------
  // planMerge
  // ---------------------------------------------------------------------------
  group('planMerge', () {
    test('keepId が組に無ければ ArgumentError', () {
      final group = DuplicateBookGroup(
        isbnKey: '9784065191234',
        books: [mk(id: 'b1'), mk(id: 'b2')],
      );
      expect(
        () => DuplicateBookService.planMerge(group, 'zzz'),
        throwsArgumentError,
      );
    });

    test('merged は keep の id を保つ', () {
      final group = DuplicateBookGroup(
        isbnKey: '9784065191234',
        books: [mk(id: 'b1'), mk(id: 'b2')],
      );
      final plan = DuplicateBookService.planMerge(group, 'b2');
      expect(plan.merged.id, 'b2');
    });

    test('title / author は keep が空なら組内で最初の非空', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', title: '', author: ''),
          mk(id: 'b2', title: '題名2', author: '著者2'),
          mk(id: 'b3', title: '題名3', author: '著者3'),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.title, '題名2');
      expect(plan.merged.author, '著者2');
    });

    test('title は keep が非空なら keep を優先', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', title: 'keep題名'),
          mk(id: 'b2', title: '他題名'),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.title, 'keep題名');
    });

    test('isbn は keep の生値を保つ', () {
      final group = DuplicateBookGroup(
        isbnKey: '9784065191234',
        books: [
          mk(id: 'b1', isbn: '9784065191234'),
          mk(id: 'b2', isbn: '978-4-06-519123-4'),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b2');
      expect(plan.merged.isbn, '978-4-06-519123-4');
    });

    test('coverImageUrl/publisher/publishedDate/pageCount は keep ?? 最初の非null',
        () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1'),
          mk(
            id: 'b2',
            coverImageUrl: 'url2',
            publisher: 'pub2',
            publishedDate: '2020-01-01',
            pageCount: null,
          ),
          mk(
            id: 'b3',
            coverImageUrl: 'url3',
            publisher: 'pub3',
            publishedDate: '2021-01-01',
            pageCount: 300,
          ),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.coverImageUrl, 'url2');
      expect(plan.merged.publisher, 'pub2');
      expect(plan.merged.publishedDate, '2020-01-01');
      expect(plan.merged.pageCount, 300);
    });

    test('keep に値があればそれを優先する', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(
            id: 'b1',
            coverImageUrl: 'keepUrl',
            publisher: 'keepPub',
            publishedDate: '1999-01-01',
            pageCount: 111,
          ),
          mk(id: 'b2', coverImageUrl: 'other', publisher: 'other', pageCount: 999),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.coverImageUrl, 'keepUrl');
      expect(plan.merged.publisher, 'keepPub');
      expect(plan.merged.publishedDate, '1999-01-01');
      expect(plan.merged.pageCount, 111);
    });

    test('description は最も長い非空文字列を採る', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', description: 'あああ'),
          mk(id: 'b2', description: 'あああああ'),
          mk(id: 'b3', description: ''),
          mk(id: 'b4'),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.description, 'あああああ');
    });

    test('description が同長なら keep を採る', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', description: 'AAAA'),
          mk(id: 'b2', description: 'BBBB'),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.description, 'AAAA');
    });

    test('description が全て空/null なら null', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', description: ''),
          mk(id: 'b2'),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.description, isNull);
    });

    test('genres は正規化した全冊の和集合（空除外・大小無視・初出順）', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', genres: ['Fiction', 'sci-fi']),
          mk(id: 'b2', genres: ['fiction', '', '   ', 'SF']),
          mk(id: 'b3', genres: ['ＳＦ']),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.genres, ['fiction', 'sci-fi', 'sf']);
    });

    test('location は keep が非空ならそれ', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', location: '棚A'),
          mk(id: 'b2', location: '棚B'),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.location, '棚A');
    });

    test('location は keep が空なら最初の非空', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', location: ''),
          mk(id: 'b2', location: null),
          mk(id: 'b3', location: '棚C'),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.location, '棚C');
    });

    test('readingStatus は finished > reading > unread', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', readingStatus: ReadingStatus.unread),
          mk(id: 'b2', readingStatus: ReadingStatus.reading),
        ],
      );
      expect(
        DuplicateBookService.planMerge(group, 'b1').merged.readingStatus,
        ReadingStatus.reading,
      );

      final group2 = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', readingStatus: ReadingStatus.reading),
          mk(id: 'b2', readingStatus: ReadingStatus.finished),
        ],
      );
      expect(
        DuplicateBookService.planMerge(group2, 'b1').merged.readingStatus,
        ReadingStatus.finished,
      );
    });

    test('currentPage は全冊の最大値', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', currentPage: 10),
          mk(id: 'b2', currentPage: 300),
          mk(id: 'b3', currentPage: 5),
        ],
      );
      expect(
        DuplicateBookService.planMerge(group, 'b1').merged.currentPage,
        300,
      );
    });

    test('finishedAt は keep ?? 最初の非null', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', finishedAt: null),
          mk(id: 'b2', finishedAt: dt(2)),
          mk(id: 'b3', finishedAt: dt(3)),
        ],
      );
      final plan = DuplicateBookService.planMerge(group, 'b1');
      expect(plan.merged.finishedAt, dt(2));

      final group2 = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', finishedAt: dt(9)),
          mk(id: 'b2', finishedAt: dt(2)),
        ],
      );
      expect(
        DuplicateBookService.planMerge(group2, 'b1').merged.finishedAt,
        dt(9),
      );
    });

    test('addedAt は最も早い非null', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [
          mk(id: 'b1', addedAt: null),
          mk(id: 'b2', addedAt: dt(5)),
          mk(id: 'b3', addedAt: dt(2)),
        ],
      );
      expect(
        DuplicateBookService.planMerge(group, 'b1').merged.addedAt,
        dt(2),
      );
    });

    test('addedAt が全て null なら null', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [mk(id: 'b1'), mk(id: 'b2')],
      );
      expect(
        DuplicateBookService.planMerge(group, 'b1').merged.addedAt,
        isNull,
      );
    });

    test('removedIds は keep 以外を組の順序で返し removedCount が一致する', () {
      final group = DuplicateBookGroup(
        isbnKey: 'k',
        books: [mk(id: 'b1'), mk(id: 'b2'), mk(id: 'b3')],
      );
      final plan = DuplicateBookService.planMerge(group, 'b2');
      expect(plan.removedIds, ['b1', 'b3']);
      expect(plan.removedCount, 2);
    });

    test('group を変更しない', () {
      final b1 = mk(id: 'b1', title: '', addedAt: dt(1));
      final b2 = mk(id: 'b2', title: '題名', addedAt: dt(2));
      final group = DuplicateBookGroup(isbnKey: 'k', books: [b1, b2]);

      DuplicateBookService.planMerge(group, 'b1');

      expect(group.books, [same(b1), same(b2)]);
      expect(group.isbnKey, 'k');
    });
  });

  // ---------------------------------------------------------------------------
  // summaryLabel
  // ---------------------------------------------------------------------------
  group('summaryLabel', () {
    test('空なら重複なしの文言', () {
      expect(
        DuplicateBookService.summaryLabel(const []),
        '重複した蔵書はありません',
      );
    });

    test('2組・計5冊の文言', () {
      final groups = [
        DuplicateBookGroup(isbnKey: 'k1', books: [
          mk(id: 'a1'),
          mk(id: 'a2'),
          mk(id: 'a3'),
        ]),
        DuplicateBookGroup(isbnKey: 'k2', books: [
          mk(id: 'b1'),
          mk(id: 'b2'),
        ]),
      ];
      expect(
        DuplicateBookService.summaryLabel(groups),
        '重複した蔵書が 2組（5冊）あります',
      );
    });
  });
}
