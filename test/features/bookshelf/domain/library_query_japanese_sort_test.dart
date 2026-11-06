import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:flutter_test/flutter_test.dart';

Book _b(String id, {required String title, DateTime? addedAt}) {
  return Book(
    id: id,
    title: title,
    author: '著者',
    isbn: '',
    addedAt: addedAt,
    readingStatus: ReadingStatus.unread,
  );
}

List<String> _ids(List<Book> books) => books.map((b) => b.id).toList();

void main() {
  group('titleAsc: 日本語かな順', () {
    test('ひらがなは あ→ん の順に並ぶ', () {
      final books = [
        _b('1', title: 'ん'),
        _b('2', title: 'あ'),
        _b('3', title: 'い'),
        _b('4', title: 'う'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(_ids(out), ['2', '3', '4', '1']);
    });

    test('カタカナが混在しても あ→ん の順になる（かなは漢字より前）', () {
      final books = [
        _b('1', title: 'ん'),
        _b('2', title: 'イ'),
        _b('3', title: 'あ'),
        _b('4', title: 'ウ'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(_ids(out), ['3', '2', '4', '1']);
    });

    test('かなは漢字・英字より前に来る', () {
      final books = [
        _b('1', title: '漢字の本'),
        _b('2', title: 'Alpha'),
        _b('3', title: 'ん'),
        _b('4', title: 'あ'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(_ids(out), ['4', '3', '2', '1']);
    });

    test('空の書名はかなの後・漢字等の先頭に来る', () {
      final books = [
        _b('1', title: '漢字'),
        _b('2', title: ''),
        _b('3', title: 'ん'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(_ids(out), ['3', '2', '1']);
    });

    test('前後の空白は順序に影響しない', () {
      final books = [
        _b('1', title: '  ん  '),
        _b('2', title: 'あ'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(_ids(out), ['2', '1']);
    });

    test('安定ソート: 同一書名（表記ゆれ含む）は元index昇順', () {
      final books = [
        _b('x', title: 'あ'),
        _b('y', title: 'ア'),
        _b('z', title: 'あ'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(_ids(out), ['x', 'y', 'z']);
    });

    test('国名・記号・数字が混在してもクラッシュせず全件返す', () {
      final books = [
        _b('1', title: '9'),
        _b('2', title: 'あいう'),
        _b('3', title: '「記号」'),
        _b('4', title: 'ん'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(out.length, 4);
      expect(_ids(out).take(2).toList(), ['2', '4']);
    });
  });
}
