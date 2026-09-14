import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';

BookNote buildNote({
  String id = 'note-1',
  String bookId = 'book-1',
  NoteKind kind = NoteKind.memo,
  String content = '気づきメモ',
  int? pageNumber,
  List<String> tags = const [],
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return BookNote(
    id: id,
    bookId: bookId,
    kind: kind,
    content: content,
    pageNumber: pageNumber,
    tags: tags,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: updatedAt,
  );
}

void main() {
  group('NoteKind', () {
    test('ラベルを持つ', () {
      expect(NoteKind.memo.label, 'メモ');
      expect(NoteKind.quote.label, '引用');
    });

    test('parseは名前から復元する', () {
      expect(NoteKind.parse('quote'), NoteKind.quote);
      expect(NoteKind.parse('memo'), NoteKind.memo);
    });

    test('parseは未知の値をmemoへフォールバックする', () {
      expect(NoteKind.parse('unknown'), NoteKind.memo);
      expect(NoteKind.parse(null), NoteKind.memo);
    });
  });

  group('BookNote 不変条件', () {
    test('idが空ならAssertionError', () {
      expect(
        () => buildNote(id: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('bookIdが空ならAssertionError', () {
      expect(
        () => buildNote(bookId: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('本文が空白のみならAssertionError', () {
      expect(
        () => buildNote(content: '   '),
        throwsA(isA<AssertionError>()),
      );
    });

    test('ページ番号が0以下ならAssertionError', () {
      expect(
        () => buildNote(pageNumber: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('ページ番号が1なら生成できる', () {
      expect(buildNote(pageNumber: 1).pageNumber, 1);
    });
  });

  group('タグの正規化', () {
    test('前後の空白を除去する', () {
      final note = buildNote(tags: ['  学び  ', '実践']);
      expect(note.tags, ['学び', '実践']);
    });

    test('空文字は除外する', () {
      final note = buildNote(tags: ['', '  ', '学び']);
      expect(note.tags, ['学び']);
    });

    test('重複は出現順を保って除去する', () {
      final note = buildNote(tags: ['a', 'b', 'a']);
      expect(note.tags, ['a', 'b']);
    });

    test('タグは変更不可である', () {
      final note = buildNote(tags: ['a']);
      expect(() => note.tags.add('b'), throwsUnsupportedError);
    });
  });

  group('表示用ヘルパ', () {
    test('pageLabelは未指定ならページ未指定', () {
      expect(buildNote().pageLabel, 'ページ未指定');
    });

    test('pageLabelは指定時はp.番号', () {
      expect(buildNote(pageNumber: 12).pageLabel, 'p.12');
    });

    test('isQuoteは引用のみ真', () {
      expect(buildNote(kind: NoteKind.quote).isQuote, isTrue);
      expect(buildNote().isQuote, isFalse);
    });

    test('excerptは上限を超える時だけ省略記号を付す', () {
      expect(buildNote(content: 'あいうえお').excerpt(maxLength: 10), 'あいうえお');
      expect(buildNote(content: 'あいうえお').excerpt(maxLength: 3), 'あいう…');
    });
  });

  group('copyWith', () {
    test('本文と種別を更新できる', () {
      final note = buildNote(content: '元', kind: NoteKind.memo);
      final updated = note.copyWith(content: '新', kind: NoteKind.quote);
      expect(updated.content, '新');
      expect(updated.kind, NoteKind.quote);
      expect(updated.id, note.id);
      expect(updated.bookId, note.bookId);
    });

    test('clearPageNumberでページ番号を消せる', () {
      final note = buildNote(pageNumber: 5);
      expect(note.copyWith(clearPageNumber: true).pageNumber, isNull);
    });

    test('updatedAtを省略した場合は元の値を保つ', () {
      final note = buildNote(updatedAt: DateTime(2026, 2, 2));
      expect(note.copyWith(content: 'x').updatedAt, DateTime(2026, 2, 2));
    });
  });

  group('JSON往復', () {
    test('全項目が復元される', () {
      final note = buildNote(
        kind: NoteKind.quote,
        content: '引用文',
        pageNumber: 42,
        tags: ['学び'],
        createdAt: DateTime(2026, 3, 1, 10),
        updatedAt: DateTime(2026, 3, 2, 11),
      );
      final restored = BookNote.fromJson(note.toJson());

      expect(restored.id, note.id);
      expect(restored.bookId, note.bookId);
      expect(restored.kind, NoteKind.quote);
      expect(restored.content, '引用文');
      expect(restored.pageNumber, 42);
      expect(restored.tags, ['学び']);
      expect(restored.createdAt, DateTime(2026, 3, 1, 10));
      expect(restored.updatedAt, DateTime(2026, 3, 2, 11));
    });

    test('pageNumberがnullでも往復できる', () {
      final note = buildNote();
      expect(BookNote.fromJson(note.toJson()).pageNumber, isNull);
    });

    test('idが欠落ならFormatException', () {
      final map = buildNote().toJson()..remove('id');
      expect(() => BookNote.fromJson(map), throwsFormatException);
    });

    test('contentが空白のみならFormatException', () {
      final map = buildNote().toJson()..['content'] = '  ';
      expect(() => BookNote.fromJson(map), throwsFormatException);
    });

    test('pageNumberが不正ならFormatException', () {
      final map = buildNote().toJson()..['pageNumber'] = 0;
      expect(() => BookNote.fromJson(map), throwsFormatException);
    });

    test('createdAtが不正ならFormatException', () {
      final map = buildNote().toJson()..['createdAt'] = 'not-a-date';
      expect(() => BookNote.fromJson(map), throwsFormatException);
    });

    test('updatedAtが欠落ならcreatedAtで補う', () {
      final map = buildNote().toJson()..remove('updatedAt');
      final restored = BookNote.fromJson(map);
      expect(restored.updatedAt, restored.createdAt);
    });

    test('未知のkindはmemoへフォールバックする', () {
      final map = buildNote().toJson()..['kind'] = 'unknown';
      expect(BookNote.fromJson(map).kind, NoteKind.memo);
    });
  });

  group('等価性', () {
    test('同じidなら等しい', () {
      expect(buildNote(id: 'x'), buildNote(id: 'x', content: '別'));
    });

    test('違うidなら等しくない', () {
      expect(buildNote(id: 'x') == buildNote(id: 'y'), isFalse);
    });
  });
}
