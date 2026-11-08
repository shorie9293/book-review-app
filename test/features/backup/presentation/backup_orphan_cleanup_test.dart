import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/presentation/backup_screen.dart';
import 'package:book_review_app/features/bookshelf/data/book_deletion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book(String id) => Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
      addedAt: DateTime.utc(2026, 1, 1),
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 5,
      text: '書評 $id',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ $id',
      createdAt: DateTime.utc(2026, 3, 3),
    );

/// 孤児掃除の検証用に、削除を記録しつつ実体を消すフェイク群。
class _OrphanStore {
  _OrphanStore({
    required this.books,
    required this.reviews,
    required this.notes,
  });

  final List<Book> books;
  final List<Review> reviews;
  final List<BookNote> notes;

  final List<String> deletedReviewIds = [];
  final List<String> deletedNoteIds = [];

  BookDeletionService service() => BookDeletionService(
        deleteReviewById: (id) async {
          deletedReviewIds.add(id);
          reviews.removeWhere((review) => review.id == id);
        },
        deleteNoteById: (id) async {
          deletedNoteIds.add(id);
          notes.removeWhere((note) => note.id == id);
        },
      );
}

void main() {
  late _OrphanStore store;
  late InMemoryBackupRepository repository;

  setUp(() {
    store = _OrphanStore(
      books: [_book('b1')],
      reviews: [_review('r1', 'b1')],
      notes: [_note('n1', 'b1')],
    );
    repository = InMemoryBackupRepository(
      books: store.books,
      reviews: store.reviews,
      notes: store.notes,
    );
  });

  /// 孤児（本の無いレビュー・メモ）を追加する。
  void addGhostData() {
    store.reviews.add(_review('r-ghost', 'b-gone'));
    store.notes.add(_note('n-ghost', 'b-gone'));
  }

  /// 節最下部のボタンまでスクロールしてから押す。
  Future<void> tapCleanupButton(WidgetTester tester) async {
    final button = find.byKey(const Key('orphan_cleanup_button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<List<Review>> Function()? allReviewsLoader,
    BookDeletionService? orphanCleanupService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          repository: repository,
          clipboardWriter: (value) async {},
          allReviewsLoader: allReviewsLoader,
          orphanCleanupService: orphanCleanupService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未指定なら「保存先を失ったデータ」節を出さない', (tester) async {
    await pumpScreen(tester);

    expect(find.text('保存先を失ったデータ'), findsNothing);
    expect(find.byKey(const Key('orphan_cleanup_button')), findsNothing);
  });

  testWidgets('孤児が0件なら節を出さない', (tester) async {
    await pumpScreen(
      tester,
      allReviewsLoader: () async => [_review('r1', 'b1')],
      orphanCleanupService: store.service(),
    );

    expect(find.text('保存先を失ったデータ'), findsNothing);
    expect(find.byKey(const Key('orphan_cleanup_button')), findsNothing);
    expect(store.deletedReviewIds, isEmpty);
    expect(store.deletedNoteIds, isEmpty);
  });

  testWidgets('孤児があると summaryLabel を出す', (tester) async {
    addGhostData();
    await pumpScreen(
      tester,
      allReviewsLoader: () async => List.of(store.reviews),
      orphanCleanupService: store.service(),
    );

    expect(find.text('保存先を失ったデータ'), findsOneWidget);
    expect(find.text('本の無い書評 1件／メモ 1件'), findsOneWidget);
    expect(find.byKey(const Key('orphan_cleanup_button')), findsOneWidget);
    // 表示だけでは削除しない
    expect(store.deletedReviewIds, isEmpty);
    expect(store.deletedNoteIds, isEmpty);
  });

  testWidgets('「刈り取る」は押すまで削除を呼ばず、キャンセルでも呼ばない', (tester) async {
    addGhostData();
    await pumpScreen(
      tester,
      allReviewsLoader: () async => List.of(store.reviews),
      orphanCleanupService: store.service(),
    );

    await tapCleanupButton(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(store.deletedReviewIds, isEmpty);
    expect(store.deletedNoteIds, isEmpty);

    await tester.tap(find.byKey(const Key('orphan_cleanup_cancel')));
    await tester.pumpAndSettle();

    expect(store.deletedReviewIds, isEmpty);
    expect(store.deletedNoteIds, isEmpty);
    expect(find.text('本の無い書評 1件／メモ 1件'), findsOneWidget);
  });

  testWidgets('確定で deleteOrphans が呼ばれ、節が消える', (tester) async {
    addGhostData();
    await pumpScreen(
      tester,
      allReviewsLoader: () async => List.of(store.reviews),
      orphanCleanupService: store.service(),
    );

    await tapCleanupButton(tester);
    await tester.tap(find.byKey(const Key('orphan_cleanup_confirm')));
    await tester.pumpAndSettle();

    expect(store.deletedReviewIds, ['r-ghost']);
    expect(store.deletedNoteIds, ['n-ghost']);
    expect(find.text('刈り取り完了: 成功 2件 / 失敗 0件'), findsOneWidget);
    expect(find.text('保存先を失ったデータ'), findsNothing);
    expect(find.byKey(const Key('orphan_cleanup_button')), findsNothing);
  });

  testWidgets('全レビュー読み出しが例外なら節を出さない（画面は落ちない）', (tester) async {
    await pumpScreen(
      tester,
      allReviewsLoader: () async => throw StateError('読み出し失敗'),
      orphanCleanupService: store.service(),
    );

    expect(find.text('保存先を失ったデータ'), findsNothing);
    expect(find.text('バックアップ対象'), findsOneWidget);
  });
}
