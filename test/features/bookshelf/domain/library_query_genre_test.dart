import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';

Book _book(
  String id, {
  String title = '',
  List<String> genres = const [],
  ReadingStatus status = ReadingStatus.unread,
}) {
  return Book(
    id: id,
    title: title,
    author: '',
    isbn: '',
    genres: genres,
    readingStatus: status,
  );
}

void main() {
  group('LibraryQueryService.apply × genres', () {
    test('genres指定で該当本のみに絞る（OR条件）', () {
      final books = [
        _book('1', genres: ['技術書']),
        _book('2', genres: ['小説']),
        _book('3', genres: ['ビジネス書']),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(genres: {'技術書', 'ビジネス書'}),
      );
      expect(out.map((b) => b.id).toSet(), {'1', '3'});
    });

    test('genresは正規化比較（前後空白・全角スペースを吸収）', () {
      final books = [
        _book('1', genres: ['技術書']),
        _book('2', genres: ['小説']),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(genres: {' 技術書　'}),
      );
      expect(out.single.id, '1');
    });

    test('genresが空ならジャンルに関係なく全件対象（回帰）', () {
      final books = [
        _book('1', title: '猫', genres: ['小説']),
        _book('2', title: '犬', genres: ['小説']),
        _book('3', title: '猫', genres: const []),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: '猫'),
      );
      // ジャンル絞込みが空でも text 絞込みは従来通り働き、
      // ジャンル無しの本も落とされない
      expect(out.length, 2);
      expect(out.map((b) => b.id).toSet(), {'1', '3'});
    });

    test('activeFilterCount が genres 1件で+1、clearGenres で 0 に戻る', () {
      const base = LibraryQuery();
      expect(base.activeFilterCount, 0);

      final withGenre = base.copyWith(genres: {'小説'});
      expect(withGenre.genres, {'小説'});
      expect(withGenre.activeFilterCount, 1);
      expect(withGenre.isDefault, isFalse);

      final cleared = withGenre.copyWith(clearGenres: true);
      expect(cleared.genres, isEmpty);
      expect(cleared.activeFilterCount, 0);
      expect(cleared.isDefault, isTrue);
    });

    test('text × genres の複合（AND）が効く', () {
      final books = [
        _book('1', title: 'Dart入門', genres: ['技術書']),
        _book('2', title: 'Dart入門', genres: ['小説']),
        _book('3', title: 'Java入門', genres: ['技術書']),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'dart', genres: {'技術書'}),
      );
      expect(out.single.id, '1');
    });
  });
}
