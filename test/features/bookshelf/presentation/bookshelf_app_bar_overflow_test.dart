import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/reading_queue_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/features/about/presentation/about_app_keys.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';

class _FakeBookRepository implements BookRepository {
  @override
  Future<List<Book>> getBooks() async => [];
  @override
  Future<Book?> getBookById(String id) async => null;
  @override
  Future<Book?> findByIsbn(String isbn) async => null;
  @override
  Future<void> addBook(Book book) async {}
  @override
  Future<void> updateBook(Book book) async {}
  @override
  Future<void> removeBook(String id) async {}
}

class _FakeReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => [];
  @override
  Future<void> addReview(Review review) async {}
  @override
  Future<void> updateReview(Review review) async {}
  @override
  Future<void> deleteReview(String id) async {}
}

class _FakeNoteRepository implements BookNoteRepository {
  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async => [];
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

class _FakeQueueRepository implements ReadingQueueRepository {
  @override
  Future<List<ReadingQueueEntry>> loadEntries() async => [];
  @override
  Future<void> saveEntries(List<ReadingQueueEntry> entries) async {}
}

class _FakeLoanRepository implements BookLoanRepository {
  @override
  Future<List<BookLoan>> loadLoans() async => [];
  @override
  Future<void> saveLoans(List<BookLoan> loans) async {}
}

/// 本番（main_screen）と同等に全導線を有効化した本棚。
Widget _fullShelf() {
  return BookshelfScreen(
    repository: _FakeBookRepository(),
    reviewRepository: _FakeReviewRepository(),
    noteRepository: _FakeNoteRepository(),
    queueRepository: _FakeQueueRepository(),
    loanRepository: _FakeLoanRepository(),
    textScale: 1.0,
    onScaleChanged: (_) {},
    themeMode: ThemeModeSetting.system,
    onThemeModeChanged: (_) {},
    reduceMotion: ReduceMotionSetting.system,
    onReduceMotionChanged: (_) {},
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  required Size logical,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = Size(logical.width * 3, logical.height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: inner!,
      ),
      home: child,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// AppBar の actions に直置きされているアイコンボタンの数。
int _inlineActionCount(WidgetTester tester) {
  final appBar = find.byType(AppBar);
  return find
      .descendant(of: appBar, matching: find.byType(IconButton))
      .evaluate()
      .length;
}

void main() {
  group('本棚 AppBar: 実機幅360dpで溢れない', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('360x780・textScaler=$scale で overflow 例外が出ない',
          (tester) async {
        await _pump(
          tester,
          child: BookshelfScreen(repository: _FakeBookRepository()),
          logical: const Size(360, 780),
          scale: scale,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('本番同等（全導線有効）でも 360x780 で overflow しない',
        (tester) async {
      await _pump(
        tester,
        child: _fullShelf(),
        logical: const Size(360, 780),
        scale: 1.0,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('文字サイズ最大（2.0）でも本番同等の 360dp で overflow しない',
        (tester) async {
      await _pump(
        tester,
        child: _fullShelf(),
        logical: const Size(360, 780),
        scale: 2.0,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('本棚 AppBar: 畳んだ操作へ到達できる', () {
    testWidgets('狭幅では「その他」メニューが現れ、主要操作は直置きのまま',
        (tester) async {
      await _pump(
        tester,
        child: _fullShelf(),
        logical: const Size(360, 780),
      );

      expect(find.byKey(AppKeys.bookshelfMoreActions), findsOneWidget);
      // 主要操作（追加・読書時間）は直置きで押せる。
      expect(find.byKey(const Key('scan_barcode_button')), findsOneWidget);
      expect(find.byKey(AppKeys.readingTimerButton), findsOneWidget);
      // 畳まれた操作は直置きされていない。
      expect(find.byKey(const Key('about_entry')), findsNothing);
    });

    testWidgets('「その他」を開くと畳んだ操作が並び、タップで遷移する',
        (tester) async {
      await _pump(
        tester,
        child: _fullShelf(),
        logical: const Size(360, 780),
      );

      await tester.tap(find.byKey(AppKeys.bookshelfMoreActions));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('about_entry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('about_entry')));
      await tester.pumpAndSettle();

      expect(find.byKey(AboutAppKeys.screen), findsOneWidget);
    });

    testWidgets('全17操作が「直置き」か「その他」のどちらかで到達できる',
        (tester) async {
      await _pump(
        tester,
        child: _fullShelf(),
        logical: const Size(360, 780),
      );

      const keys = <String>[
        'stats_button',
        'recommendation_button',
        'stagnant_books_button',
        'challenge_button',
        'scan_barcode_button',
        'bulk_import_button',
        'reading_queue_button',
        'open_favorites_button',
        'backup_button',
        'text_scale_settings_button',
        'about_entry',
        'daily_goal_entry',
        'app_lock_entry',
        'reading_reminder_entry',
      ];
      final missingInline = <String>[];
      for (final k in keys) {
        if (find.byKey(Key(k)).evaluate().isEmpty) missingInline.add(k);
      }
      // 直置きされていないものはメニューに居なければならない。
      await tester.tap(find.byKey(AppKeys.bookshelfMoreActions));
      await tester.pumpAndSettle();
      for (final k in missingInline) {
        expect(find.byKey(Key(k)), findsOneWidget,
            reason: '$k が直置きにも「その他」にも無い');
      }
    });

    testWidgets('広い画面（既定800dp）では従来通り全件直置き＝「その他」は出ない',
        (tester) async {
      await _pump(
        tester,
        child: BookshelfScreen(repository: _FakeBookRepository()),
        logical: const Size(800, 600),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(AppKeys.bookshelfMoreActions), findsNothing);
      expect(find.byKey(const Key('stats_button')), findsOneWidget);
      expect(find.byKey(const Key('about_entry')), findsOneWidget);
      expect(_inlineActionCount(tester), greaterThanOrEqualTo(10));
    });
  });

  group('絞込バー: 狭幅＋文字拡大でも溢れない', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('360x780・textScaler=$scale で overflow 例外が出ない',
          (tester) async {
        await _pump(
          tester,
          child: BookshelfScreen(repository: _FakeBookRepository()),
          logical: const Size(360, 780),
          scale: scale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
