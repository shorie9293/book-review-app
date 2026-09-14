import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_card.dart';

BookNote note({
  NoteKind kind = NoteKind.memo,
  String content = '気づきのメモ',
  int? pageNumber,
  List<String> tags = const [],
  DateTime? createdAt,
}) {
  return BookNote(
    id: 'n1',
    bookId: 'book-1',
    kind: kind,
    content: content,
    pageNumber: pageNumber,
    tags: tags,
    createdAt: createdAt ?? DateTime(2026, 3, 4),
  );
}

Future<void> pumpCard(
  WidgetTester tester,
  BookNote value, {
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NoteCard(
          note: value,
          onEdit: onEdit ?? () {},
          onDelete: onDelete ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('NoteCard', () {
    testWidgets('本文・ページ・日付を表示する', (tester) async {
      await pumpCard(tester, note(pageNumber: 12));

      expect(find.byKey(const Key('note_card_content')), findsOneWidget);
      expect(find.text('気づきのメモ'), findsOneWidget);
      expect(find.text('p.12'), findsOneWidget);
      expect(find.text('2026/3/4'), findsOneWidget);
    });

    testWidgets('ページ未指定はページ未指定と表示する', (tester) async {
      await pumpCard(tester, note());
      expect(find.text('ページ未指定'), findsOneWidget);
    });

    testWidgets('種別バッジにメモと表示する', (tester) async {
      await pumpCard(tester, note());
      final badge = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('note_card_kind_badge')),
          matching: find.byType(Text),
        ),
      );
      expect(badge.data, 'メモ');
    });

    testWidgets('引用はバッジに引用と表示する', (tester) async {
      await pumpCard(tester, note(kind: NoteKind.quote));
      final badge = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('note_card_kind_badge')),
          matching: find.byType(Text),
        ),
      );
      expect(badge.data, '引用');
    });

    testWidgets('タグがある場合のみタグ領域を表示する', (tester) async {
      await pumpCard(tester, note(tags: ['学び', '実践']));
      expect(find.byKey(const Key('note_card_tags')), findsOneWidget);
      expect(find.text('学び'), findsOneWidget);
      expect(find.text('実践'), findsOneWidget);
    });

    testWidgets('タグが無ければタグ領域を表示しない', (tester) async {
      await pumpCard(tester, note());
      expect(find.byKey(const Key('note_card_tags')), findsNothing);
    });

    testWidgets('編集ボタンでonEditが呼ばれる', (tester) async {
      var edited = 0;
      await pumpCard(tester, note(), onEdit: () => edited++);
      await tester.tap(find.byKey(const Key('note_card_edit_button')));
      expect(edited, 1);
    });

    testWidgets('削除ボタンでonDeleteが呼ばれる', (tester) async {
      var deleted = 0;
      await pumpCard(tester, note(), onDelete: () => deleted++);
      await tester.tap(find.byKey(const Key('note_card_delete_button')));
      expect(deleted, 1);
    });
  });
}
