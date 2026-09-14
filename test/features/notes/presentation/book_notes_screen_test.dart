import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/book_notes_screen.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_card.dart';

/// 遅延付きリポジトリ（ローディング状態の検証用）
class DelayedBookNoteRepository implements BookNoteRepository {
  final Duration delay;
  final List<BookNote> notes;

  DelayedBookNoteRepository({
    this.delay = const Duration(seconds: 1),
    this.notes = const [],
  });

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async {
    await Future<void>.delayed(delay);
    return notes.where((n) => n.bookId == bookId).toList();
  }

  @override
  Future<List<BookNote>> getAllNotes() async => notes;

  @override
  Future<void> addNote(BookNote note) async {}

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> deleteNotesByBookId(String bookId) async {}
}

BookNote note({
  required String id,
  String bookId = 'book-1',
  NoteKind kind = NoteKind.memo,
  String content = '本文',
  int? pageNumber,
  List<String> tags = const [],
}) {
  return BookNote(
    id: id,
    bookId: bookId,
    kind: kind,
    content: content,
    pageNumber: pageNumber,
    tags: tags,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> pumpScreen(
  WidgetTester tester,
  BookNoteRepository repository, {
  String? bookTitle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BookNotesScreen(
        bookId: 'book-1',
        repository: repository,
        bookTitle: bookTitle,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late InMemoryBookNoteRepository repository;

  setUp(() {
    repository = InMemoryBookNoteRepository();
  });

  group('BookNotesScreen 表示', () {
    testWidgets('メモが無ければ空状態を表示する', (tester) async {
      await pumpScreen(tester, repository);
      expect(find.byKey(const Key('note_empty_state')), findsOneWidget);
    });

    testWidgets('読み込み中はローディングを表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookNotesScreen(
            bookId: 'book-1',
            repository: DelayedBookNoteRepository(
              notes: [note(id: 'n1')],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('note_loading_state')), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key('note_loading_state')), findsNothing);
    });

    testWidgets('メモをページ順でカード表示する', (tester) async {
      await repository.addNote(note(id: 'n2', pageNumber: 30, content: '後半'));
      await repository.addNote(note(id: 'n1', pageNumber: 5, content: '前半'));
      await pumpScreen(tester, repository);

      final cards = tester.widgetList<NoteCard>(find.byType(NoteCard));
      expect(cards.length, 2);
      expect(find.text('前半'), findsOneWidget);
      expect(find.text('後半'), findsOneWidget);
    });

    testWidgets('サマリに件数とページ範囲を表示する', (tester) async {
      await repository.addNote(note(id: 'n1', pageNumber: 5));
      await repository.addNote(
          note(id: 'n2', kind: NoteKind.quote, pageNumber: 40));
      await pumpScreen(tester, repository);

      expect(find.text('メモ 1件 ・ 引用 1件'), findsOneWidget);
      expect(find.text('p.5〜p.40'), findsOneWidget);
    });

    testWidgets('書名が渡されればタイトルに含める', (tester) async {
      await pumpScreen(tester, repository, bookTitle: '吾輩は猫である');
      expect(find.text('読書メモ: 吾輩は猫である'), findsOneWidget);
    });

    testWidgets('書名が無ければ読書メモとだけ表示する', (tester) async {
      await pumpScreen(tester, repository);
      expect(find.text('読書メモ'), findsOneWidget);
    });

    testWidgets('他書籍のメモは表示しない', (tester) async {
      await repository.addNote(note(id: 'n1', bookId: 'book-2'));
      await pumpScreen(tester, repository);
      expect(find.byKey(const Key('note_empty_state')), findsOneWidget);
    });
  });

  group('BookNotesScreen 操作', () {
    testWidgets('FABからメモを追加できる', (tester) async {
      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('note_add_fab')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('note_form_content')), '新しい気づき');
      await tester.enterText(find.byKey(const Key('note_form_page')), '10');
      await tester.tap(find.byKey(const Key('note_form_save')));
      await tester.pumpAndSettle();

      expect(find.text('新しい気づき'), findsOneWidget);
      expect(find.text('p.10'), findsOneWidget);
      expect(repository.length, 1);
    });

    testWidgets('フィルタチップで種別を絞り込める', (tester) async {
      await repository.addNote(note(id: 'n1', content: 'メモ本文'));
      await repository.addNote(
          note(id: 'n2', kind: NoteKind.quote, content: '引用本文'));
      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('note_filter_quote')));
      await tester.pumpAndSettle();
      expect(find.text('引用本文'), findsOneWidget);
      expect(find.text('メモ本文'), findsNothing);

      await tester.tap(find.byKey(const Key('note_filter_memo')));
      await tester.pumpAndSettle();
      expect(find.text('メモ本文'), findsOneWidget);
      expect(find.text('引用本文'), findsNothing);

      await tester.tap(find.byKey(const Key('note_filter_all')));
      await tester.pumpAndSettle();
      expect(find.byType(NoteCard), findsNWidgets(2));
    });

    testWidgets('検索フィールドで本文を絞り込める', (tester) async {
      await repository.addNote(note(id: 'n1', content: 'Flutterの話'));
      await repository.addNote(note(id: 'n2', content: '別の話'));
      await pumpScreen(tester, repository);

      await tester.enterText(
          find.byKey(const Key('note_search_field')), 'flutter');
      await tester.pumpAndSettle();

      expect(find.text('Flutterの話'), findsOneWidget);
      expect(find.text('別の話'), findsNothing);
    });

    testWidgets('編集で内容を更新できる', (tester) async {
      await repository.addNote(note(id: 'n1', content: '旧本文'));
      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('note_card_edit_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('note_form_content')), '新本文');
      await tester.tap(find.byKey(const Key('note_form_save')));
      await tester.pumpAndSettle();

      expect(find.text('新本文'), findsOneWidget);
      expect(find.text('旧本文'), findsNothing);
    });

    testWidgets('削除確認で削除できる', (tester) async {
      await repository.addNote(note(id: 'n1', content: '消す本文'));
      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('note_card_delete_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('note_delete_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.text('消す本文'), findsNothing);
      expect(repository.length, 0);
      expect(find.byKey(const Key('note_empty_state')), findsOneWidget);
    });

    testWidgets('削除をキャンセルすると残る', (tester) async {
      await repository.addNote(note(id: 'n1', content: '残る本文'));
      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('note_card_delete_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('note_delete_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('残る本文'), findsOneWidget);
      expect(repository.length, 1);
    });
  });
}
