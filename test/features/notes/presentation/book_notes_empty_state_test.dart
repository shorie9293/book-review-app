import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/widgets/empty_state.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/book_notes_screen.dart';

/// 読書メモ画面の空状態が共通部品で描かれ、行動ボタンから既存の
/// 追加導線（メモ入力ダイアログ）へ繋がることを撃つ試練。
void main() {
  late InMemoryBookNoteRepository repository;

  setUp(() {
    repository = InMemoryBookNoteRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookNotesScreen(bookId: 'book-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('メモ0件では共通部品の空状態と行動ボタンを出す', (tester) async {
    await pump(tester);

    // 既存文言・既存 Key は変えていない。
    expect(find.text('メモはまだありません'), findsOneWidget);
    expect(find.byKey(const Key('note_empty_state')), findsOneWidget);
    expect(find.byKey(EmptyStateView.actionButtonKey), findsOneWidget);
    expect(find.text('メモを書く'), findsOneWidget);
  });

  testWidgets('空状態の行動ボタンを押すとメモ入力ダイアログが開く', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(EmptyStateView.actionButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
