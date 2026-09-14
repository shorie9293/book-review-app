import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/notes/presentation/viewmodel/book_notes_view_model.dart';

/// 例外を投げるリポジトリ（エラー状態の検証用）
class ThrowingBookNoteRepository implements BookNoteRepository {
  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async {
    throw StateError('読み込み失敗');
  }

  @override
  Future<List<BookNote>> getAllNotes() async => [];

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

void main() {
  late InMemoryBookNoteRepository repository;
  late BookNotesViewModel viewModel;

  setUp(() {
    repository = InMemoryBookNoteRepository();
    viewModel = BookNotesViewModel();
  });

  group('loadNotes', () {
    test('読み込み後にisLoadingがfalseになる', () async {
      await viewModel.loadNotes(repository, 'book-1');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.bookId, 'book-1');
    });

    test('該当書籍のメモをソート順で保持する', () async {
      await repository.addNote(note(id: 'n2', pageNumber: 20));
      await repository.addNote(note(id: 'n1', pageNumber: 5));
      await viewModel.loadNotes(repository, 'book-1');
      expect(viewModel.notes.map((n) => n.id), ['n1', 'n2']);
    });

    test('例外時はerrorMessageを設定し空リストにする', () async {
      await viewModel.loadNotes(ThrowingBookNoteRepository(), 'book-1');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.notes, isEmpty);
    });

    test('通知が発火する', () async {
      var notified = 0;
      viewModel.addListener(() => notified++);
      await viewModel.loadNotes(repository, 'book-1');
      expect(notified, greaterThan(0));
    });
  });

  group('絞り込み', () {
    setUp(() async {
      await repository.addNote(note(id: 'm1', content: 'メモ本文'));
      await repository.addNote(
          note(id: 'q1', kind: NoteKind.quote, content: '引用本文', tags: ['学び']));
      await viewModel.loadNotes(repository, 'book-1');
    });

    test('種別フィルタで絞り込める', () {
      viewModel.setKindFilter(NoteKind.quote);
      expect(viewModel.visibleNotes.map((n) => n.id), ['q1']);
      viewModel.setKindFilter(null);
      expect(viewModel.visibleNotes.length, 2);
    });

    test('キーワードでタグも検索できる', () {
      viewModel.setKeyword('学び');
      expect(viewModel.visibleNotes.map((n) => n.id), ['q1']);
    });

    test('キーワードが空なら全件', () {
      viewModel.setKeyword('  ');
      expect(viewModel.visibleNotes.length, 2);
    });

    test('countByKind・tagCounts・pageRangeを公開する', () {
      expect(viewModel.countByKind[NoteKind.memo], 1);
      expect(viewModel.countByKind[NoteKind.quote], 1);
      expect(viewModel.tagCounts['学び'], 1);
      expect(viewModel.pageRange.isEmpty, isTrue);
    });

    test('quotesで引用のみ取得できる', () {
      expect(viewModel.quotes.map((n) => n.id), ['q1']);
    });

    test('setKindFilterは同一値で通知しない', () {
      final before = viewModel.kindFilter;
      var notified = 0;
      viewModel.addListener(() => notified++);
      viewModel.setKindFilter(before);
      expect(notified, 0);
    });
  });

  group('変更操作', () {
    setUp(() async {
      await viewModel.loadNotes(repository, 'book-1');
    });

    test('追加すると一覧に反映される', () async {
      await viewModel.addNote(repository, note(id: 'n1', pageNumber: 3));
      expect(viewModel.notes.map((n) => n.id), ['n1']);
    });

    test('更新すると内容が反映される', () async {
      await viewModel.addNote(repository, note(id: 'n1', content: '旧'));
      await viewModel.updateNote(
          repository, note(id: 'n1', content: '新', pageNumber: 9));
      expect(viewModel.notes.single.content, '新');
      expect(viewModel.notes.single.pageNumber, 9);
    });

    test('削除すると一覧から消える', () async {
      await viewModel.addNote(repository, note(id: 'n1'));
      await viewModel.deleteNote(repository, 'n1');
      expect(viewModel.notes, isEmpty);
    });
  });
}
