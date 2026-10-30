import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/book_notes_screen.dart';
import 'package:book_review_app/features/undo/presentation/undo_snack_bar.dart';

/// メモ削除 → 「元に戻す」→ 復元 の合成試練。
void main() {
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
    InMemoryBookNoteRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookNotesScreen(bookId: 'book-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> deleteNote(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('note_card_delete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('note_delete_confirm_button')));
    await tester.pumpAndSettle();
  }

  group('メモ削除の元に戻す', () {
    testWidgets('削除確認の直後に「元に戻す」SnackBar が出る', (tester) async {
      final repository = InMemoryBookNoteRepository();
      await repository.addNote(note(id: 'n1', content: '消える本文'));
      await pumpScreen(tester, repository);

      await deleteNote(tester);

      expect(repository.length, 0);
      expect(find.text('メモを削除しました'), findsOneWidget);
      expect(find.byKey(undoActionKey), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);
    });

    testWidgets('「元に戻す」タップで同じメモが復元され一覧へ即反映される', (tester) async {
      final repository = InMemoryBookNoteRepository();
      await repository.addNote(note(
        id: 'n1',
        content: '復元される本文',
        pageNumber: 12,
        tags: const ['気づき'],
      ));
      await pumpScreen(tester, repository);

      await deleteNote(tester);
      expect(find.text('復元される本文'), findsNothing);
      expect(find.byKey(const Key('note_empty_state')), findsOneWidget);

      await tester.tap(find.byKey(undoActionKey));
      await tester.pumpAndSettle();

      // repository に復元（id が保たれる）
      expect(repository.length, 1);
      final restored = (await repository.getNotesByBookId('book-1')).single;
      expect(restored.id, 'n1');
      expect(restored.content, '復元される本文');
      expect(restored.pageNumber, 12);
      expect(restored.tags, const ['気づき']);

      // 画面の再読込経路が走り、内容が戻る
      expect(find.text('復元される本文'), findsOneWidget);
      expect(find.text('p.12'), findsOneWidget);
      expect(find.byKey(const Key('note_empty_state')), findsNothing);
    });

    testWidgets('「元に戻す」は二重復元できない', (tester) async {
      final repository = InMemoryBookNoteRepository();
      await repository.addNote(note(id: 'n1', content: '一度きり'));
      await pumpScreen(tester, repository);

      await deleteNote(tester);
      await tester.tap(find.byKey(undoActionKey));
      await tester.pumpAndSettle();

      expect(find.byKey(undoActionKey), findsNothing);
      expect(repository.length, 1);
    });

    testWidgets('確認ダイアログでキャンセルすれば SnackBar は出ない', (tester) async {
      final repository = InMemoryBookNoteRepository();
      await repository.addNote(note(id: 'n1', content: '残る本文'));
      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('note_card_delete_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('note_delete_cancel_button')));
      await tester.pumpAndSettle();

      expect(repository.length, 1);
      expect(find.byKey(undoActionKey), findsNothing);
      expect(find.text('メモを削除しました'), findsNothing);
    });
  });

  group('HiveBookNoteRepository の id 保持（復元の前提）', () {
    final tempDir = Directory.systemTemp.createTempSync('book_notes_undo');
    late HiveBookNoteRepository repository;

    setUp(() async {
      Hive.init(tempDir.path);
      repository = HiveBookNoteRepository();
      await repository.init(boxName: 'book_notes_undo');
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('book_notes_undo');
      await Hive.close();
    });

    test('deleteNote → addNote で同じ id のまま復元される', () async {
      final original = note(id: 'hive-n1', content: '保存される本文', pageNumber: 7);
      await repository.addNote(original);
      await repository.deleteNote('hive-n1');
      expect(await repository.getNotesByBookId('book-1'), isEmpty);

      await repository.addNote(original);

      final restored = (await repository.getNotesByBookId('book-1')).single;
      expect(restored.id, 'hive-n1');
      expect(restored.content, '保存される本文');
      expect(restored.pageNumber, 7);
    });
  });
}
