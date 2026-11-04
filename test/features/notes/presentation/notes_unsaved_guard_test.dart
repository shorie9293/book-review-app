import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/input/draft_store.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/book_notes_screen.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_form.dart';

/// メモリ上のメモリポジトリ。
class _MemoryNoteRepository implements BookNoteRepository {
  final Map<String, BookNote> _store = {};

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async =>
      _store.values.where((n) => n.bookId == bookId).toList();

  @override
  Future<List<BookNote>> getAllNotes() async => _store.values.toList();

  @override
  Future<void> addNote(BookNote note) async {
    _store[note.id] = note;
  }

  @override
  Future<void> updateNote(BookNote note) async {
    _store[note.id] = note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> deleteNotesByBookId(String bookId) async {
    _store.removeWhere((_, note) => note.bookId == bookId);
  }
}

Widget _app({
  required BookNoteRepository repository,
  DraftStore? draftStore,
}) {
  return MaterialApp(
    home: BookNotesScreen(
      bookId: 'book-1',
      repository: repository,
      draftStore: draftStore,
    ),
  );
}

Future<void> _openAddDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('note_add_fab')));
  await tester.pumpAndSettle();
}

Future<void> _tapOutside(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('未入力なら外側タップで従来どおり閉じる', (tester) async {
    await tester.pumpWidget(_app(
      repository: _MemoryNoteRepository(),
      draftStore: InMemoryDraftStore(),
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);

    await _tapOutside(tester);

    expect(find.byType(NoteForm), findsNothing);
    expect(find.byKey(const Key('unsaved_changes_dialog')), findsNothing);
  });

  testWidgets('入力後に外側タップすると確認が出て、編集を続けると本文が残る', (tester) async {
    await tester.pumpWidget(_app(
      repository: _MemoryNoteRepository(),
      draftStore: InMemoryDraftStore(),
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);
    await tester.enterText(
      find.byKey(const Key('note_form_content')),
      '書きかけの引用メモ',
    );
    await tester.pumpAndSettle();

    await _tapOutside(tester);

    expect(find.byType(NoteForm), findsOneWidget);
    expect(find.byKey(const Key('unsaved_changes_dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('unsaved_changes_keep')));
    await tester.pumpAndSettle();

    expect(find.text('書きかけの引用メモ'), findsOneWidget);
  });

  testWidgets('破棄して閉じても下書きが残り、本文・ページ・タグが復元される', (tester) async {
    final store = InMemoryDraftStore();
    await tester.pumpWidget(_app(
      repository: _MemoryNoteRepository(),
      draftStore: store,
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);
    await tester.enterText(find.byKey(const Key('note_form_content')), '長い引用の下書き');
    await tester.enterText(find.byKey(const Key('note_form_page')), '42');
    await tester.enterText(find.byKey(const Key('note_form_tags')), '引用, 深い');
    await tester.pumpAndSettle();

    await _tapOutside(tester);
    await tester.tap(find.byKey(const Key('unsaved_changes_discard')));
    await tester.pumpAndSettle();
    expect(find.byType(NoteForm), findsNothing);

    expect(
      await store.read(BookNotesScreen.draftKeyForNew('book-1')),
      contains('長い引用の下書き'),
    );

    await _openAddDialog(tester);
    expect(find.text('長い引用の下書き'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('引用, 深い'), findsOneWidget);
  });

  testWidgets('保存に成功すると下書きが消える', (tester) async {
    final store = InMemoryDraftStore();
    await tester.pumpWidget(_app(
      repository: _MemoryNoteRepository(),
      draftStore: store,
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);
    await tester.enterText(find.byKey(const Key('note_form_content')), '保存するメモ');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note_form_save')));
    await tester.pumpAndSettle();

    expect(find.byType(NoteForm), findsNothing);
    expect(await store.read(BookNotesScreen.draftKeyForNew('book-1')), isNull);
  });
}
