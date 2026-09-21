import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';

Book _b(
  String id, {
  String title = '',
  String author = '',
  int? pageCount,
  DateTime? addedAt,
  ReadingStatus status = ReadingStatus.unread,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    isbn: '',
    pageCount: pageCount,
    addedAt: addedAt,
    readingStatus: status,
  );
}

void main() {
  group('LibrarySortOrder', () {
    test('全ソート順に日本語labelがある', () {
      expect(LibrarySortOrder.titleAsc.label, isNotEmpty);
      expect(LibrarySortOrder.addedAtDesc.label, isNotEmpty);
      expect(LibrarySortOrder.addedAtAsc.label, isNotEmpty);
      expect(LibrarySortOrder.pageCountDesc.label, isNotEmpty);
      expect(LibrarySortOrder.pageCountAsc.label, isNotEmpty);
      expect(LibrarySortOrder.statusAsc.label, isNotEmpty);
    });
  });

  group('LibraryQuery', () {
    test('既定は addedAtDesc かつ isDefault が true', () {
      const q = LibraryQuery();
      expect(q.sortOrder, LibrarySortOrder.addedAtDesc);
      expect(q.text, '');
      expect(q.statuses, isEmpty);
      expect(q.isDefault, isTrue);
      expect(q.activeFilterCount, 0);
    });

    test('activeFilterCount は text + statuses + 非既定ソートを数える', () {
      const q = LibraryQuery(
        text: '吾輩',
        statuses: {ReadingStatus.unread, ReadingStatus.reading},
        sortOrder: LibrarySortOrder.titleAsc,
      );
      expect(q.activeFilterCount, 4);
      expect(q.isDefault, isFalse);
    });

    test('copyWith で text/statuses/sortOrder を更新できる', () {
      const base = LibraryQuery();
      final q = base.copyWith(
        text: 'xyz',
        statuses: {ReadingStatus.finished},
        sortOrder: LibrarySortOrder.pageCountAsc,
      );
      expect(q.text, 'xyz');
      expect(q.statuses, {ReadingStatus.finished});
      expect(q.sortOrder, LibrarySortOrder.pageCountAsc);
    });

    test('copyWith(clearText: true) で text を消せる', () {
      final q = const LibraryQuery(text: 'abc').copyWith(clearText: true);
      expect(q.text, '');
    });

    test('copyWith(clearStatuses: true) で statuses を消せる', () {
      final q = const LibraryQuery(statuses: {
        ReadingStatus.reading,
      }).copyWith(clearStatuses: true);
      expect(q.statuses, isEmpty);
    });
  });

  group('LibraryQueryService.apply', () {
    final t0 = DateTime(2026, 1, 1);
    final t1 = DateTime(2026, 2, 1);
    final t2 = DateTime(2026, 3, 1);

    test('既定クエリでは元の順序を保つ（非破壊）', () {
      final books = [_b('a'), _b('b'), _b('c')];
      final copy = List<Book>.from(books);
      final out = LibraryQueryService.apply(books, const LibraryQuery());
      expect(out.map((b) => b.id).toList(), ['a', 'b', 'c']);
      expect(books.map((b) => b.id).toList(), copy.map((b) => b.id).toList());
    });

    test('normalize: 全角英数字・全角スペース・大文字小文字を吸収', () {
      final books = [
        _b('1', title: 'Ｄａｒｔ入門'),
        _b('2', title: 'Java入門'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'dart'),
      );
      expect(out.single.id, '1');
    });

    test('normalize: 全角スペース区切りの複数語で著者を部分一致', () {
      final books = [
        _b('1', title: '徒然草', author: '吉田 兼好'),
        _b('2', title: '方丈記', author: '鴨長明'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: '吉田　兼好'),
      );
      expect(out.single.id, '1');
    });

    test('空白のみのtextはフィルタしない', () {
      final books = [_b('1', title: '本'), _b('2', title: '本')];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: ' 　'),
      );
      expect(out.length, 2);
    });

    test('statusesが空なら全状態を返す', () {
      final books = [
        _b('1', status: ReadingStatus.unread),
        _b('2', status: ReadingStatus.reading),
        _b('3', status: ReadingStatus.finished),
      ];
      final out = LibraryQueryService.apply(books, const LibraryQuery());
      expect(out.length, 3);
    });

    test('statusesで絞り込める', () {
      final books = [
        _b('1', status: ReadingStatus.unread),
        _b('2', status: ReadingStatus.reading),
        _b('3', status: ReadingStatus.finished),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(statuses: {ReadingStatus.reading}),
      );
      expect(out.single.id, '2');
    });

    test('textとstatusesのAND絞込', () {
      final books = [
        _b('1', title: '吾輩は猫である', status: ReadingStatus.unread),
        _b('2', title: '吾輩は猫である', status: ReadingStatus.finished),
        _b('3', title: '坊ちゃん', status: ReadingStatus.unread),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: '猫', statuses: {ReadingStatus.unread}),
      );
      expect(out.single.id, '1');
    });

    test('titleAsc: 書名昇順', () {
      final books = [
        _b('1', title: 'う'),
        _b('2', title: 'あ'),
        _b('3', title: 'い'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(out.map((b) => b.id).toList(), ['2', '3', '1']);
    });

    test('addedAtDesc: 追加日降順', () {
      final books = [
        _b('1', addedAt: t0),
        _b('2', addedAt: t2),
        _b('3', addedAt: t1),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.addedAtDesc),
      );
      expect(out.map((b) => b.id).toList(), ['2', '3', '1']);
    });

    test('addedAtAsc: 追加日昇順', () {
      final books = [
        _b('1', addedAt: t2),
        _b('2', addedAt: t0),
        _b('3', addedAt: t1),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.addedAtAsc),
      );
      expect(out.map((b) => b.id).toList(), ['2', '3', '1']);
    });

    test('addedAtソートでnullの本は元index順を保持', () {
      final books = [
        _b('1', addedAt: t1),
        _b('2'), // null
        _b('3', addedAt: t2),
        _b('4'), // null
        _b('5', addedAt: t0),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.addedAtAsc),
      );
      // nullは最古扱いで先頭に寄せられ、null同士は元index順（2→4）
      final ids = out.map((b) => b.id).toList();
      expect(ids, ['2', '4', '5', '1', '3']);
      expect(ids.indexOf('2') < ids.indexOf('4'), isTrue);
    });

    test('pageCountDesc: ページ数降順・nullは末尾', () {
      final books = [
        _b('1', pageCount: 100),
        _b('2'),
        _b('3', pageCount: 300),
        _b('4', pageCount: 200),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.pageCountDesc),
      );
      expect(out.map((b) => b.id).toList(), ['3', '4', '1', '2']);
    });

    test('pageCountAsc: ページ数昇順・nullは末尾', () {
      final books = [
        _b('1', pageCount: 200),
        _b('2'),
        _b('3', pageCount: 100),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.pageCountAsc),
      );
      expect(out.map((b) => b.id).toList(), ['3', '1', '2']);
    });

    test('statusAsc: unread→reading→finished', () {
      final books = [
        _b('1', status: ReadingStatus.finished),
        _b('2', status: ReadingStatus.unread),
        _b('3', status: ReadingStatus.reading),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.statusAsc),
      );
      expect(out.map((b) => b.id).toList(), ['2', '3', '1']);
    });

    test('安定ソート: 同一追加日は元index昇順', () {
      final books = [
        _b('a', addedAt: t0),
        _b('b', addedAt: t0),
        _b('c', addedAt: t0),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.addedAtDesc),
      );
      expect(out.map((b) => b.id).toList(), ['a', 'b', 'c']);
    });

    test('安定ソート: 同一書名は元index昇順', () {
      final books = [
        _b('x', title: '同じ', addedAt: t0),
        _b('y', title: '同じ', addedAt: t1),
        _b('z', title: '同じ', addedAt: t2),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(out.map((b) => b.id).toList(), ['x', 'y', 'z']);
    });

    test('入力リストを変更しない', () {
      final books = [
        _b('1', title: 'い', addedAt: t1),
        _b('2', title: 'ろ', addedAt: t0),
      ];
      final snapshot = books.map((b) => b.id).toList();
      LibraryQueryService.apply(
        books,
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc),
      );
      expect(books.map((b) => b.id).toList(), snapshot);
    });

    test('titleがnullでも落ちない', () {
      final books = [
        Book(id: '1', title: '', author: '', isbn: ''),
      ];
      final out = LibraryQueryService.apply(books, const LibraryQuery());
      expect(out, isNotEmpty);
    });

    test('空リストで空を返す', () {
      final out = LibraryQueryService.apply([], const LibraryQuery());
      expect(out, isEmpty);
    });
  });
}
