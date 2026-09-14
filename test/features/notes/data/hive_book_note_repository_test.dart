import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';

BookNote note({
  required String id,
  String bookId = 'book-1',
  NoteKind kind = NoteKind.memo,
  String content = '本文',
  int? pageNumber,
  List<String> tags = const [],
  DateTime? createdAt,
}) {
  return BookNote(
    id: id,
    bookId: bookId,
    kind: kind,
    content: content,
    pageNumber: pageNumber,
    tags: tags,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  late Directory tempDir;
  late HiveBookNoteRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_notes_test_');
    Hive.init(tempDir.path);
    repository = HiveBookNoteRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await Hive.deleteBoxFromDisk(HiveBookNoteRepository.defaultBoxName);
    tempDir.deleteSync(recursive: true);
  });

  group('HiveBookNoteRepository', () {
    test('追加したメモを書籍IDで取得できる', () async {
      await repository.addNote(note(id: 'n1', content: '気づき'));
      final notes = await repository.getNotesByBookId('book-1');
      expect(notes.length, 1);
      expect(notes.first.id, 'n1');
      expect(notes.first.content, '気づき');
    });

    test('ページ番号・種別・タグが往復する', () async {
      await repository.addNote(note(
        id: 'n1',
        kind: NoteKind.quote,
        pageNumber: 42,
        tags: ['学び', '実践'],
      ));
      final restored = (await repository.getAllNotes()).single;
      expect(restored.kind, NoteKind.quote);
      expect(restored.pageNumber, 42);
      expect(restored.tags, ['学び', '実践']);
    });

    test('別の書籍のメモは混ざらない', () async {
      await repository.addNote(note(id: 'n1', bookId: 'book-1'));
      await repository.addNote(note(id: 'n2', bookId: 'book-2'));
      expect((await repository.getNotesByBookId('book-1')).length, 1);
      expect((await repository.getAllNotes()).length, 2);
    });

    test('ページ順にソートして返す', () async {
      await repository.addNote(note(id: 'n2', pageNumber: 20));
      await repository.addNote(note(id: 'n1', pageNumber: 5));
      expect(
        (await repository.getNotesByBookId('book-1')).map((n) => n.id),
        ['n1', 'n2'],
      );
    });

    test('更新すると内容が差し替わる', () async {
      await repository.addNote(note(id: 'n1', content: '旧'));
      await repository.updateNote(note(id: 'n1', content: '新'));
      final notes = await repository.getNotesByBookId('book-1');
      expect(notes.length, 1);
      expect(notes.single.content, '新');
    });

    test('削除できる', () async {
      await repository.addNote(note(id: 'n1'));
      await repository.deleteNote('n1');
      expect(await repository.getAllNotes(), isEmpty);
    });

    test('書籍IDでまとめて削除できる', () async {
      await repository.addNote(note(id: 'n1', bookId: 'book-1'));
      await repository.addNote(note(id: 'n2', bookId: 'book-1'));
      await repository.addNote(note(id: 'n3', bookId: 'book-2'));
      await repository.deleteNotesByBookId('book-1');
      final remaining = await repository.getAllNotes();
      expect(remaining.map((n) => n.id), ['n3']);
    });

    test('破損エントリは読み飛ばす', () async {
      await repository.addNote(note(id: 'ok'));
      final box = Hive.box<String>(HiveBookNoteRepository.defaultBoxName);
      await box.put('broken-json', '{not json');
      await box.put('broken-model', '{"id":"x","bookId":"","content":"y"}');

      final notes = await repository.getAllNotes();
      expect(notes.map((n) => n.id), ['ok']);
    });

    test('空の場合は空リストを返す', () async {
      expect(await repository.getAllNotes(), isEmpty);
      expect(await repository.getNotesByBookId('none'), isEmpty);
    });
  });

  group('InMemoryBookNoteRepository', () {
    test('追加・取得・更新・削除ができる', () async {
      final repo = InMemoryBookNoteRepository();
      await repo.addNote(note(id: 'n1', pageNumber: 3));
      await repo.addNote(note(id: 'n2', pageNumber: 1));

      expect((await repo.getNotesByBookId('book-1')).map((n) => n.id),
          ['n2', 'n1']);
      expect(repo.length, 2);

      await repo.updateNote(note(id: 'n1', content: '改'));
      expect((await repo.getAllNotes())
          .firstWhere((n) => n.id == 'n1')
          .content, '改');

      await repo.deleteNote('n1');
      expect(repo.length, 1);
    });

    test('書籍IDでまとめて削除できる', () async {
      final repo = InMemoryBookNoteRepository();
      await repo.addNote(note(id: 'n1', bookId: 'book-1'));
      await repo.addNote(note(id: 'n2', bookId: 'book-2'));
      await repo.deleteNotesByBookId('book-1');
      expect((await repo.getAllNotes()).map((n) => n.id), ['n2']);
    });
  });
}
