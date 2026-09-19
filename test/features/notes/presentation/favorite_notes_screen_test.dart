import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/favorite_notes_screen.dart';

/// FavoriteNotesScreen のテスト。
class _ThrowingRepository implements BookNoteRepository {
  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async {
    throw Exception('読み込み失敗');
  }

  @override
  Future<List<BookNote>> getAllNotes() async {
    throw Exception('読み込み失敗');
  }

  @override
  Future<void> addNote(BookNote note) async {}

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> deleteNotesByBookId(String bookId) async {}
}

void main() {
  BookNote note({
    required String id,
    required String bookId,
    required bool favorite,
  }) {
    return BookNote(
      id: id,
      bookId: bookId,
      kind: NoteKind.quote,
      content: '本文-$id',
      isFavorite: favorite,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required BookNoteRepository repository,
    List<Book> books = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FavoriteNotesScreen(repository: repository, books: books),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('お気に入りが空なら空状態を表示する', (tester) async {
    await pumpScreen(tester, repository: InMemoryBookNoteRepository());
    expect(find.byKey(const Key('favorite_empty_state')), findsOneWidget);
    expect(find.text('お気に入りの引用はまだありません'), findsOneWidget);
  });

  testWidgets('お気に入りのみを表示し、非お気に入りは出さない', (tester) async {
    final repository = InMemoryBookNoteRepository();
    await repository.addNote(note(id: 'n1', bookId: 'b1', favorite: true));
    await repository.addNote(note(id: 'n2', bookId: 'b1', favorite: false));
    await pumpScreen(tester, repository: repository);

    expect(find.byKey(const ValueKey('favorite_note_n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('favorite_note_n2')), findsNothing);
    expect(find.byKey(const Key('favorite_empty_state')), findsNothing);
  });

  testWidgets('書籍タイトルを表示する（未知は「不明な書籍」）', (tester) async {
    final repository = InMemoryBookNoteRepository();
    await repository.addNote(note(id: 'n1', bookId: 'b1', favorite: true));
    await repository.addNote(note(id: 'n2', bookId: 'bX', favorite: true));
    await pumpScreen(
      tester,
      repository: repository,
      books: const [Book(id: 'b1', title: '吾輩は猫である', author: '夏目漱石', isbn: '')],
    );

    expect(find.text('吾輩は猫である'), findsOneWidget);
    expect(find.text('不明な書籍'), findsOneWidget);
    expect(find.text('本文-n1'), findsOneWidget);
  });

  testWidgets('読み込み失敗時はエラー状態を表示する', (tester) async {
    await pumpScreen(tester, repository: _ThrowingRepository());
    expect(find.byKey(const Key('favorite_error_state')), findsOneWidget);
  });
}
