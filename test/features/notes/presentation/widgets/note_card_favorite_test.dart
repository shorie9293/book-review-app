import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_card.dart';

/// NoteCard のお気に入りボタンのテスト。
void main() {
  BookNote note({bool isFavorite = false}) {
    return BookNote(
      id: 'n1',
      bookId: 'b1',
      kind: NoteKind.quote,
      content: '引用本文',
      isFavorite: isFavorite,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required BookNote note,
    VoidCallback? onToggleFavorite,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            note: note,
            onEdit: () {},
            onDelete: () {},
            onToggleFavorite: onToggleFavorite,
          ),
        ),
      ),
    );
  }

  testWidgets('onToggleFavorite 未指定時は星ボタンを表示しない', (tester) async {
    await pumpCard(tester, note: note());
    expect(find.byKey(const Key('note_card_favorite_button')), findsNothing);
  });

  testWidgets('onToggleFavorite 指定時は星ボタンを表示する', (tester) async {
    await pumpCard(tester, note: note(), onToggleFavorite: () {});
    expect(find.byKey(const Key('note_card_favorite_button')), findsOneWidget);
  });

  testWidgets('未お気に入りでは star_border を表示する', (tester) async {
    await pumpCard(tester, note: note(), onToggleFavorite: () {});
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('note_card_favorite_button')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.star_border);
  });

  testWidgets('お気に入りでは star（amber）を表示する', (tester) async {
    await pumpCard(
      tester,
      note: note(isFavorite: true),
      onToggleFavorite: () {},
    );
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('note_card_favorite_button')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.star);
    expect(icon.color, Colors.amber);
  });

  testWidgets('タップでコールバックが発火する', (tester) async {
    var called = 0;
    await pumpCard(tester, note: note(), onToggleFavorite: () => called++);
    await tester.tap(find.byKey(const Key('note_card_favorite_button')));
    expect(called, 1);
  });
}
