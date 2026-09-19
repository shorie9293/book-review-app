import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/features/notes/domain/book_note_service.dart';

/// BookNoteService のお気に入り純粋ロジックのテスト。
void main() {
  BookNote note(
    String id,
    String bookId, {
    int? page,
    required bool favorite,
    DateTime? createdAt,
  }) {
    return BookNote(
      id: id,
      bookId: bookId,
      kind: NoteKind.quote,
      content: '本文-$id',
      pageNumber: page,
      isFavorite: favorite,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );
  }

  group('favoritesOf', () {
    test('isFavorite のみを抽出する', () {
      final notes = [
        note('n1', 'b1', favorite: false),
        note('n2', 'b1', favorite: true),
        note('n3', 'b2', favorite: true),
      ];
      final result = BookNoteService.favoritesOf(notes);
      expect(result.map((n) => n.id), ['n2', 'n3']);
    });

    test('bookId 昇順 → ページ昇順 → 作成日時昇順 → id 昇順でソートされる', () {
      final notes = [
        note('n4', 'b2', page: 5, favorite: true),
        note('n1', 'b1', page: 10, favorite: true),
        note('n3', 'b1', page: 2, favorite: true),
        note('n2', 'b1', page: 2, favorite: true, createdAt: DateTime(2026, 1, 1)),
        note('n2x', 'b1', page: 2, favorite: true, createdAt: DateTime(2026, 1, 1)),
      ];
      final result = BookNoteService.favoritesOf(notes);
      expect(result.map((n) => n.id), ['n2', 'n2x', 'n3', 'n1', 'n4']);
    });

    test('ページ未指定は末尾に配置される', () {
      final notes = [
        note('n2', 'b1', favorite: true),
        note('n1', 'b1', page: 3, favorite: true),
      ];
      final result = BookNoteService.favoritesOf(notes);
      expect(result.map((n) => n.id), ['n1', 'n2']);
    });

    test('入力リストを非破壊する', () {
      final notes = [
        note('n2', 'b2', favorite: true),
        note('n1', 'b1', favorite: true),
      ];
      final before = List.of(notes);
      BookNoteService.favoritesOf(notes);
      expect(notes.map((n) => n.id), before.map((n) => n.id));
    });
  });

  group('favoritesByBook', () {
    test('bookId でグループ化され、キーは昇順', () {
      final notes = [
        note('n2', 'b2', favorite: true),
        note('n1', 'b1', favorite: true),
        note('n3', 'b1', favorite: false),
      ];
      final result = BookNoteService.favoritesByBook(notes);
      expect(result.keys.toList(), ['b1', 'b2']);
      expect(result['b1']!.map((n) => n.id), ['n1']);
      expect(result['b2']!.map((n) => n.id), ['n2']);
    });

    test('お気に入りがなければ空', () {
      final notes = [note('n1', 'b1', favorite: false)];
      expect(BookNoteService.favoritesByBook(notes), isEmpty);
    });
  });

  group('favoriteCount', () {
    test('お気に入り件数を返す', () {
      final notes = [
        note('n1', 'b1', favorite: true),
        note('n2', 'b1', favorite: false),
        note('n3', 'b2', favorite: true),
      ];
      expect(BookNoteService.favoriteCount(notes), 2);
      expect(BookNoteService.favoriteCount(const []), 0);
    });
  });
}
