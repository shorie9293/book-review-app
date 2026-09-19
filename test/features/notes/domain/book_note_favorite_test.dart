import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';

/// BookNote のお気に入り機能のテスト。
void main() {
  BookNote note({
    String id = 'n1',
    bool isFavorite = false,
    NoteKind kind = NoteKind.quote,
  }) {
    return BookNote(
      id: id,
      bookId: 'b1',
      kind: kind,
      content: '引用本文',
      isFavorite: isFavorite,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('isFavorite の JSON 往復', () {
    test('toJson / fromJson で isFavorite: true が保持される', () {
      final original = note().copyWith(isFavorite: true);
      final restored = BookNote.fromJson(original.toJson());
      expect(restored.isFavorite, isTrue);
    });

    test('toJson / fromJson で isFavorite: false が保持される', () {
      final original = note();
      final restored = BookNote.fromJson(original.toJson());
      expect(restored.isFavorite, isFalse);
    });
  });

  group('fromJson の後方互換', () {
    test('キーが欠落している場合は false になる', () {
      final map = note().toJson()..remove('isFavorite');
      final restored = BookNote.fromJson(map);
      expect(restored.isFavorite, isFalse);
    });
  });

  group('toggleFavorite', () {
    test('false → true に切り替わる', () {
      final toggled = note().toggleFavorite();
      expect(toggled.isFavorite, isTrue);
    });

    test('true → false に切り替わる', () {
      final toggled = note(isFavorite: true).toggleFavorite();
      expect(toggled.isFavorite, isFalse);
    });

    test('既存フィールドが保持される', () {
      final original = BookNote(
        id: 'n2',
        bookId: 'b9',
        kind: NoteKind.quote,
        content: '別の引用',
        pageNumber: 42,
        tags: const ['座右の銘'],
        createdAt: DateTime(2026, 2, 3, 10, 30),
        updatedAt: DateTime(2026, 2, 4, 11, 0),
      ).copyWith(isFavorite: true);
      final toggled = original.toggleFavorite();

      expect(toggled.id, 'n2');
      expect(toggled.bookId, 'b9');
      expect(toggled.kind, NoteKind.quote);
      expect(toggled.content, '別の引用');
      expect(toggled.pageNumber, 42);
      expect(toggled.tags, const ['座右の銘']);
      expect(toggled.createdAt, DateTime(2026, 2, 3, 10, 30));
      expect(toggled.updatedAt, DateTime(2026, 2, 4, 11, 0));
      expect(toggled.isFavorite, isFalse);
    });
  });

  group('copyWith の isFavorite', () {
    test('デフォルトは false', () {
      expect(note().isFavorite, isFalse);
    });

    test('copyWith で変更できる', () {
      expect(note().copyWith(isFavorite: true).isFavorite, isTrue);
      expect(
        note(isFavorite: true).copyWith(isFavorite: false).isFavorite,
        isFalse,
      );
    });
  });
}
