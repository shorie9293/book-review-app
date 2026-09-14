import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_form.dart';

Future<void> pumpForm(
  WidgetTester tester, {
  BookNote? note,
  required ValueChanged<BookNote> onSave,
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NoteForm(
          bookId: 'book-1',
          note: note,
          onSave: onSave,
          onCancel: onCancel ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('NoteForm', () {
    testWidgets('本文が空ならエラーを表示しonSaveを呼ばない', (tester) async {
      BookNote? saved;
      await pumpForm(tester, onSave: (note) => saved = note);

      await tester.tap(find.byKey(const Key('note_form_save')));
      await tester.pump();

      expect(find.byKey(const Key('note_form_error')), findsOneWidget);
      expect(saved, isNull);
    });

    testWidgets('本文を入力して保存するとonSaveが呼ばれる', (tester) async {
      BookNote? saved;
      await pumpForm(tester, onSave: (note) => saved = note);

      await tester.enterText(
          find.byKey(const Key('note_form_content')), '重要な気づき');
      await tester.tap(find.byKey(const Key('note_form_save')));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.bookId, 'book-1');
      expect(saved!.content, '重要な気づき');
      expect(saved!.kind, NoteKind.memo);
      expect(saved!.pageNumber, isNull);
      expect(saved!.id, isNotEmpty);
    });

    testWidgets('ページ番号とタグを保存できる', (tester) async {
      BookNote? saved;
      await pumpForm(tester, onSave: (note) => saved = note);

      await tester.enterText(find.byKey(const Key('note_form_content')), '引用');
      await tester.enterText(find.byKey(const Key('note_form_page')), '42');
      await tester.enterText(
          find.byKey(const Key('note_form_tags')), '学び, 実践、その他');
      await tester.tap(find.byKey(const Key('note_form_save')));
      await tester.pump();

      expect(saved!.pageNumber, 42);
      expect(saved!.tags, ['学び', '実践', 'その他']);
    });

    testWidgets('ページ番号0はエラーになる', (tester) async {
      BookNote? saved;
      await pumpForm(tester, onSave: (note) => saved = note);

      await tester.enterText(find.byKey(const Key('note_form_content')), '本文');
      await tester.enterText(find.byKey(const Key('note_form_page')), '0');
      await tester.tap(find.byKey(const Key('note_form_save')));
      await tester.pump();

      expect(find.byKey(const Key('note_form_error')), findsOneWidget);
      expect(saved, isNull);
    });

    testWidgets('引用チップを選ぶとkindがquoteになる', (tester) async {
      BookNote? saved;
      await pumpForm(tester, onSave: (note) => saved = note);

      await tester.tap(find.byKey(const Key('note_form_kind_quote')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('note_form_content')), '引用文');
      await tester.tap(find.byKey(const Key('note_form_save')));
      await tester.pump();

      expect(saved!.kind, NoteKind.quote);
    });

    testWidgets('編集時は既存値が初期表示される', (tester) async {
      final existing = BookNote(
        id: 'n1',
        bookId: 'book-1',
        kind: NoteKind.quote,
        content: '既存の引用',
        pageNumber: 7,
        tags: ['学び'],
        createdAt: DateTime(2026, 1, 1),
      );
      await pumpForm(tester, note: existing, onSave: (_) {});

      expect(find.text('既存の引用'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('学び'), findsOneWidget);
    });

    testWidgets('編集して保存するとidとcreatedAtを引き継ぐ', (tester) async {
      final existing = BookNote(
        id: 'n1',
        bookId: 'book-1',
        content: '旧',
        createdAt: DateTime(2026, 1, 1),
      );
      BookNote? saved;
      await pumpForm(tester, note: existing, onSave: (note) => saved = note);

      await tester.enterText(find.byKey(const Key('note_form_content')), '新');
      await tester.tap(find.byKey(const Key('note_form_save')));
      await tester.pump();

      expect(saved!.id, 'n1');
      expect(saved!.content, '新');
      expect(saved!.createdAt, DateTime(2026, 1, 1));
    });

    testWidgets('キャンセルでonCancelが呼ばれる', (tester) async {
      var cancelled = 0;
      await pumpForm(tester, onSave: (_) {}, onCancel: () => cancelled++);
      await tester.tap(find.byKey(const Key('note_form_cancel')));
      expect(cancelled, 1);
    });
  });
}
