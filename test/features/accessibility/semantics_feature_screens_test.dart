// UX アクセシビリティ基盤 — 機能画面（キュー・引用・統計・チャレンジ・一括取込）の Semantics 試練
//
// コア画面（semantics_core_screens_test.dart）と対をなす。眷属が担った機能画面群に
// SemanticHelper の identifier と日本語ラベルが露出し、スクリーンリーダー
// （TalkBack 等）と uiautomator の content-desc から操作可能であることを検証する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/challenge/presentation/challenge_screen.dart';
import 'package:book_review_app/features/import/presentation/bulk_import_screen.dart';
import 'package:book_review_app/features/notes/presentation/favorite_notes_screen.dart';
import 'package:book_review_app/features/queue/data/hive_reading_queue_repository.dart';
import 'package:book_review_app/features/queue/presentation/reading_queue_screen.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

// ---------- テスト用の軽量フェイク ----------

Book book(String id, String title) =>
    Book(id: id, title: title, author: '著者$id', isbn: 'isbn-$id');

class _FineRepository implements BookNoteRepository {
  final List<BookNote> notes;
  _FineRepository(this.notes);

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async =>
      notes.where((n) => n.bookId == bookId).toList();

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

class _FakeStatsSource implements StatsDataSource {
  final List<Book> books;
  final List<Review> reviews;
  _FakeStatsSource({List<Book>? books, List<Review>? reviews})
      : books = books ?? [],
        reviews = reviews ?? [];

  @override
  Future<List<Book>> getBooks() async => books;

  @override
  Future<List<Review>> getAllReviews() async => reviews;
}

class _FakeChallengeRepository implements ChallengeRepository {
  _FakeChallengeRepository({this.target = 0});
  final int target;

  @override
  Future<int> getAnnualTarget() async => target;

  @override
  Future<void> setAnnualTarget(int target) async {}

  @override
  Future<List<Review>> getAllReviews() async => [];
}

class _InMemoryBookRepository implements BookRepository {
  final Map<String, Book> books = {};

  @override
  Future<List<Book>> getBooks() async => books.values.toList();

  @override
  Future<Book?> getBookById(String id) async => books[id];

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async => books[book.id] = book;

  @override
  Future<void> updateBook(Book book) async => books[book.id] = book;

  @override
  Future<void> removeBook(String id) async => books.remove(id);
}

class _FakeSearchService extends BookSearchService {
  @override
  Future<Book?> searchByIsbn(String isbn) async => null;
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingQueueScreen アクセシビリティ', () {
    testWidgets('追加FABと次に読む一冊に identifier とラベルが付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      final repo = InMemoryReadingQueueRepository();
      await repo.saveEntries([
        ReadingQueueEntry(
            bookId: 'q1', position: 1, addedAt: DateTime(2026, 9, 25)),
      ]);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(ReadingQueueScreen(
        repository: repo,
        books: [book('q1', '宇宙の本')],
      )));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('queue_add_book'), findsOneWidget);
      expect(find.bySemanticsIdentifier('queue_next_card'), findsOneWidget);

      final nextCard = find.bySemanticsIdentifier('queue_next_card');
      expect(tester.getSemantics(nextCard).label, contains('次に読む一冊'));
      handle.dispose();
    });
  });

  group('FavoriteNotesScreen アクセシビリティ', () {
    testWidgets('お気に入り一覧と引用項目に identifier とラベルが付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      final note = BookNote(
        id: 'fav1',
        bookId: 'b1',
        kind: NoteKind.quote,
        content: '心に残った一節',
        isFavorite: true,
        createdAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(_wrap(FavoriteNotesScreen(
        repository: _FineRepository([note]),
        books: [book('b1', '引用の本')],
      )));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('favorite_note_list'), findsOneWidget);
      expect(
          find.bySemanticsIdentifier('item_favorite_fav1'), findsOneWidget);

      final item = find.bySemanticsIdentifier('item_favorite_fav1');
      expect(tester.getSemantics(item).label, contains('心に残った一節'));
      handle.dispose();
    });
  });

  group('StatsScreen アクセシビリティ', () {
    testWidgets('統計カード群に identifier とラベルが付与される', (tester) async {
      final handle = tester.ensureSemantics();
      final thisYear = DateTime.now().year;
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(StatsScreen(
        dataSource: _FakeStatsSource(
          books: [
            Book(
              id: 's1',
              title: '統計の本',
              author: '著者A',
              isbn: '',
              readingStatus: ReadingStatus.finished,
              finishedAt: DateTime(thisYear, 3, 10),
            ),
          ],
          reviews: [
            Review(
              id: 'r1',
              bookId: 's1',
              rating: 5,
              text: 'text',
              createdAt: DateTime(thisYear, 3, 11),
            ),
          ],
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('stats_summary'), findsOneWidget);
      expect(find.bySemanticsIdentifier('stats_monthly'), findsOneWidget);

      final summary = find.bySemanticsIdentifier('stats_summary');
      expect(tester.getSemantics(summary).label, contains('読了'));
      handle.dispose();
    });
  });

  group('ChallengeScreen アクセシビリティ', () {
    testWidgets('進捗カードと目標設定に identifier とラベルが付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(ChallengeScreen(
        repository: _FakeChallengeRepository(target: 12),
      )));
      await tester.pumpAndSettle();

      expect(
          find.bySemanticsIdentifier('challenge_progress_card'), findsOneWidget);
      expect(find.bySemanticsIdentifier('challenge_set_goal'), findsOneWidget);

      final goal = find.bySemanticsIdentifier('challenge_set_goal');
      expect(tester.getSemantics(goal).label, contains('年間の目標冊数'));
      handle.dispose();
    });
  });

  group('BulkImportScreen アクセシビリティ', () {
    testWidgets('入力欄・解析・取込の操作要素に identifier とラベルが付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(BulkImportScreen(
        repository: _InMemoryBookRepository(),
        searchService: _FakeSearchService(),
      )));
      await tester.pump();

      expect(find.bySemanticsIdentifier('import_text_field'), findsOneWidget);
      expect(find.bySemanticsIdentifier('import_run'), findsOneWidget);

      final run = find.bySemanticsIdentifier('import_run');
      expect(tester.getSemantics(run).label, contains('蔵書を取り込む'));
      handle.dispose();
    });
  });
}
