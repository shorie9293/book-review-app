import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/genre_service.dart';

Book _book(
  String id, {
  List<String> genres = const [],
  ReadingStatus status = ReadingStatus.unread,
}) {
  return Book(
    id: id,
    title: '本$id',
    author: '著者',
    isbn: '000$id',
    genres: genres,
    readingStatus: status,
  );
}

void main() {
  group('GenreService.normalize', () {
    test('全角英数・全角スペースを半角化し小文字化・空白圧縮する', () {
      expect(GenreService.normalize('　技術書　ＡＩ '), '技術書 ai');
    });

    test('空文字は空を返す', () {
      expect(GenreService.normalize('  '), '');
    });
  });

  group('GenreService.canonicalList', () {
    test('正規化の上で重複を除去し順序を保つ', () {
      expect(
        GenreService.canonicalList(['小説', ' 小説 ', '技術書']),
        ['小説', '技術書'],
      );
    });

    test('正規化後に空になった要素は除外する', () {
      expect(GenreService.canonicalList(['  ', 'ビジネス書']), ['ビジネス書']);
    });
  });

  group('GenreService.validateNew', () {
    test('正常な追加はnullを返す', () {
      expect(GenreService.validateNew(const [], '技術書'), isNull);
    });

    test('空はエラーメッセージを返す', () {
      expect(GenreService.validateNew(const [], '  '), isNotNull);
    });

    test('既存と同名（正規化後）はエラーメッセージを返す', () {
      expect(GenreService.validateNew(const ['小説'], ' 小説 '), isNotNull);
    });

    test('上限長超過はエラーメッセージを返す', () {
      expect(
        GenreService.validateNew(const [], 'あ' * (GenreService.maxGenreLength + 1)),
        isNotNull,
      );
      expect(
        GenreService.validateNew(const [], 'あ' * GenreService.maxGenreLength),
        isNull,
      );
    });
  });

  group('GenreService.countByGenre / availableGenres', () {
    test('正規化後に集計し件数降順・同数は名前昇順', () {
      final books = [
        _book('1', genres: ['小説']),
        _book('2', genres: ['小説', '技術書']),
        _book('3', genres: ['ビジネス書']),
        _book('4', genres: [' 小説 ']),
      ];
      final counts = GenreService.countByGenre(books);
      expect(counts['小説'], 3);
      expect(counts['技術書'], 1);
      expect(counts['ビジネス書'], 1);
      expect(
        GenreService.availableGenres(books),
        ['小説', 'ビジネス書', '技術書'],
      );
    });

    test('ジャンル無しの本は無視・空リストは空', () {
      expect(GenreService.availableGenres([_book('1')]), isEmpty);
      expect(GenreService.availableGenres(const []), isEmpty);
    });
  });

  group('GenreService.matches', () {
    test('選択空は全件通過', () {
      expect(GenreService.matches(_book('1'), const <String>{}), isTrue);
    });

    test('選択ジャンルのいずれかを保持すれば通過（OR・正規化比較）', () {
      final book = _book('1', genres: ['技術書', '小説']);
      expect(GenreService.matches(book, {'技術書'}), isTrue);
      expect(GenreService.matches(book, {'技術書', 'ビジネス書'}), isTrue);
      expect(GenreService.matches(book, {'ビジネス書'}), isFalse);
      // 正規化後の一致（全角スペース差など）も通す
      expect(GenreService.matches(book, {' 技術書　'}), isTrue);
    });

    test('ジャンル無しの本は選択があれば落とされる', () {
      expect(GenreService.matches(_book('1'), {'小説'}), isFalse);
    });
  });

  group('Book.genres (additive)', () {
    test('既定は空リスト', () {
      final book = Book(id: 'a', title: 't', author: 'a', isbn: 'i');
      expect(book.genres, isEmpty);
    });

    test('copyWithでジャンルを設定・clearGenresで空に戻せる', () {
      final base = Book(id: 'a', title: 't', author: 'a', isbn: 'i');
      final withGenre = base.copyWith(genres: ['小説']);
      expect(withGenre.genres, ['小説']);
      expect(withGenre.copyWith(clearGenres: true).genres, isEmpty);
      // 他フィールドは保持
      expect(withGenre.copyWith(genres: ['技術書']).id, 'a');
    });
  });
}
