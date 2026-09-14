import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/features/notes/domain/book_note_service.dart';

BookNote note({
  required String id,
  String bookId = 'book-1',
  NoteKind kind = NoteKind.memo,
  String content = '本文',
  int? pageNumber,
  List<String> tags = const [],
  DateTime? createdAt,
}) {
  return BookNote(
    id: id,
    bookId: bookId,
    kind: kind,
    content: content,
    pageNumber: pageNumber,
    tags: tags,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('sortNotes', () {
    test('ページ昇順で並ぶ', () {
      final sorted = BookNoteService.sortNotes([
        note(id: 'c', pageNumber: 30),
        note(id: 'a', pageNumber: 10),
        note(id: 'b', pageNumber: 20),
      ]);
      expect(sorted.map((n) => n.id), ['a', 'b', 'c']);
    });

    test('ページ未指定は末尾へ回る', () {
      final sorted = BookNoteService.sortNotes([
        note(id: 'none'),
        note(id: 'p5', pageNumber: 5),
      ]);
      expect(sorted.map((n) => n.id), ['p5', 'none']);
    });

    test('同一ページは作成日時昇順→ID昇順', () {
      final sorted = BookNoteService.sortNotes([
        note(id: 'b', pageNumber: 1, createdAt: DateTime(2026, 1, 2)),
        note(id: 'a', pageNumber: 1, createdAt: DateTime(2026, 1, 1)),
        note(id: 'c', pageNumber: 1, createdAt: DateTime(2026, 1, 1)),
      ]);
      expect(sorted.map((n) => n.id), ['a', 'c', 'b']);
    });

    test('元のリストを変更しない', () {
      final input = [note(id: 'b', pageNumber: 2), note(id: 'a', pageNumber: 1)];
      BookNoteService.sortNotes(input);
      expect(input.first.id, 'b');
    });
  });

  group('notesOf', () {
    test('指定書籍のみをページ順で返す', () {
      final notes = [
        note(id: 'a', bookId: 'book-1', pageNumber: 9),
        note(id: 'b', bookId: 'book-2', pageNumber: 1),
        note(id: 'c', bookId: 'book-1', pageNumber: 3),
      ];
      expect(BookNoteService.notesOf(notes, 'book-1').map((n) => n.id),
          ['c', 'a']);
    });
  });

  group('countByKind', () {
    test('種別ごとの件数を0件も含めて返す', () {
      final counts = BookNoteService.countByKind([
        note(id: 'a'),
        note(id: 'b', kind: NoteKind.quote),
        note(id: 'c', kind: NoteKind.quote),
      ]);
      expect(counts[NoteKind.memo], 1);
      expect(counts[NoteKind.quote], 2);
    });

    test('空リストでは全種別0件', () {
      final counts = BookNoteService.countByKind([]);
      expect(counts[NoteKind.memo], 0);
      expect(counts[NoteKind.quote], 0);
    });
  });

  group('pageRange', () {
    test('ページ指定のある最小最大を返す', () {
      final range = BookNoteService.pageRange([
        note(id: 'a', pageNumber: 30),
        note(id: 'b', pageNumber: 10),
        note(id: 'c'),
      ]);
      expect(range.min, 10);
      expect(range.max, 30);
      expect(range.span, 20);
    });

    test('ページ指定が無ければisEmpty', () {
      final range = BookNoteService.pageRange([note(id: 'a')]);
      expect(range.isEmpty, isTrue);
      expect(range.span, 0);
    });

    test('1件のみならspanは0', () {
      final range = BookNoteService.pageRange([note(id: 'a', pageNumber: 7)]);
      expect(range.min, 7);
      expect(range.max, 7);
      expect(range.span, 0);
    });

    test('等価比較ができる', () {
      expect(
        const NotePageRange(min: 1, max: 2),
        const NotePageRange(min: 1, max: 2),
      );
      expect(
        const NotePageRange(min: 1, max: 2),
        isNot(const NotePageRange(min: 1, max: 3)),
      );
    });
  });

  group('tagCounts', () {
    test('件数降順→タグ名昇順で返す', () {
      final counts = BookNoteService.tagCounts([
        note(id: 'a', tags: ['x', 'y']),
        note(id: 'b', tags: ['x']),
        note(id: 'c', tags: ['y']),
        note(id: 'd', tags: ['z']),
      ]);
      expect(counts.keys.toList(), ['x', 'y', 'z']);
      expect(counts['x'], 2);
      expect(counts['z'], 1);
    });

    test('タグが無ければ空', () {
      expect(BookNoteService.tagCounts([note(id: 'a')]), isEmpty);
    });
  });

  group('groupByBook', () {
    test('書籍IDごとに分類し各リストをソートする', () {
      final grouped = BookNoteService.groupByBook([
        note(id: 'b1', bookId: 'b', pageNumber: 5),
        note(id: 'a1', bookId: 'a', pageNumber: 2),
        note(id: 'b2', bookId: 'b', pageNumber: 1),
      ]);
      expect(grouped.keys.toSet(), {'a', 'b'});
      expect(grouped['b']!.map((n) => n.id), ['b2', 'b1']);
    });
  });

  group('filterByKind', () {
    test('nullなら全件を順序保持で返す', () {
      final notes = [note(id: 'a'), note(id: 'b', kind: NoteKind.quote)];
      expect(BookNoteService.filterByKind(notes, null).length, 2);
    });

    test('引用のみ抽出できる', () {
      final notes = [note(id: 'a'), note(id: 'b', kind: NoteKind.quote)];
      final quotes = BookNoteService.filterByKind(notes, NoteKind.quote);
      expect(quotes.map((n) => n.id), ['b']);
    });
  });

  group('filterByTag', () {
    test('タグを持つメモのみ返す', () {
      final notes = [
        note(id: 'a', tags: ['学び']),
        note(id: 'b', tags: ['別']),
      ];
      expect(BookNoteService.filterByTag(notes, '学び').map((n) => n.id),
          ['a']);
    });

    test('空タグなら全件', () {
      final notes = [note(id: 'a')];
      expect(BookNoteService.filterByTag(notes, '  ').length, 1);
    });
  });

  group('search', () {
    test('本文の部分一致で抽出する（大文字小文字を無視）', () {
      final notes = [
        note(id: 'a', content: 'Flutterの学び'),
        note(id: 'b', content: '別の話'),
      ];
      expect(BookNoteService.search(notes, 'flutter').map((n) => n.id), ['a']);
    });

    test('タグの部分一致でも抽出する', () {
      final notes = [
        note(id: 'a', tags: ['dart']),
        note(id: 'b', tags: ['その他']),
      ];
      expect(BookNoteService.search(notes, 'DAR').map((n) => n.id), ['a']);
    });

    test('空キーワードなら全件', () {
      expect(BookNoteService.search([note(id: 'a')], '  ').length, 1);
    });
  });

  group('quotesOf', () {
    test('引用のみページ順で返す', () {
      final notes = [
        note(id: 'm', bookId: 'b1'),
        note(id: 'q2', bookId: 'b1', kind: NoteKind.quote, pageNumber: 20),
        note(id: 'q1', bookId: 'b1', kind: NoteKind.quote, pageNumber: 10),
        note(id: 'x', bookId: 'b2', kind: NoteKind.quote, pageNumber: 5),
      ];
      expect(BookNoteService.quotesOf(notes, 'b1').map((n) => n.id),
          ['q1', 'q2']);
    });
  });
}
