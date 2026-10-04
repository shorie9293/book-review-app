import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';

/// テスト用のインメモリ書誌リポジトリ（導線ゲート試練用）。
class FakeBookRepository implements BookRepository {
  FakeBookRepository(this._books);

  final List<Book> _books;

  @override
  Future<List<Book>> getBooks() async => List<Book>.from(_books);

  @override
  Future<Book?> getBookById(String id) async {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async => _books.add(book);

  @override
  Future<void> updateBook(Book book) async {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) _books[index] = book;
  }

  @override
  Future<void> removeBook(String id) async =>
      _books.removeWhere((book) => book.id == id);
}

ReadingSession session(
  String id, {
  String? bookTitle,
  String? bookId,
  required DateTime startedAt,
  required int minutes,
}) =>
    ReadingSession(
      id: id,
      bookId: bookId,
      bookTitle: bookTitle,
      startedAt: startedAt,
      durationMinutes: minutes,
    );

void main() {
  final base = DateTime(2026, 10, 4, 12, 0);

  Future<void> pumpScreen(
    WidgetTester tester,
    InMemoryReadingSessionRepository repository, {
    required DateTime Function() now,
  }) async {
    // 履歴カードまで一覧に収めるため縦長のサーフェスにする。
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingSessionScreen(repository: repository, now: now),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('読書時間画面', () {
    testWidgets('セッション0件なら空状態を表示する', (tester) async {
      var current = base;
      await pumpScreen(
        tester,
        InMemoryReadingSessionRepository(),
        now: () => current,
      );

      expect(find.byKey(AppKeys.readingEmpty), findsOneWidget);
      expect(find.text('まだ記録がありません'), findsOneWidget);
    });

    testWidgets('セッションを投入すると総読書時間（totalLabel）が正しく出る', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          bookTitle: '吾輩は猫である',
          bookId: 'book-1',
          startedAt: base.subtract(const Duration(days: 1)),
          minutes: 45));
      await repository.add(session('s2',
          bookTitle: '吾輩は猫である',
          bookId: 'book-1',
          startedAt: base.subtract(const Duration(days: 2)),
          minutes: 30));

      await pumpScreen(tester, repository, now: () => current);

      // 45 + 30 = 75分 → '1時間15分'
      expect(find.text('1時間15分'), findsOneWidget);
      expect(find.byKey(AppKeys.readingTotalLabel), findsOneWidget);
      expect(find.text('2回'), findsOneWidget);
      expect(find.text('1冊'), findsOneWidget);
      expect(find.text('2日'), findsOneWidget);
    });

    testWidgets('履歴行に書名・開始時刻・durationLabel が表示される', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          bookTitle: '文学の本',
          startedAt: DateTime(2026, 10, 3, 9, 5),
          minutes: 90));

      await pumpScreen(tester, repository, now: () => current);

      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsOneWidget);
      expect(find.text('文学の本'), findsOneWidget);
      expect(find.text('1時間30分'), findsOneWidget);
      expect(find.text('10/03 09:05・1時間30分'), findsOneWidget);
    });

    testWidgets('bookTitle 未紐づけのセッションは「(紐づけなし)」で表示される', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          startedAt: base.subtract(const Duration(hours: 1)), minutes: 20));

      await pumpScreen(tester, repository, now: () => current);

      expect(find.text('(紐づけなし)'), findsOneWidget);
    });

    testWidgets('削除ボタンで repository から remove され再集計される', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          bookTitle: '一冊目',
          startedAt: base.subtract(const Duration(hours: 2)),
          minutes: 30));
      await repository.add(session('s2',
          bookTitle: '二冊目',
          startedAt: base.subtract(const Duration(hours: 1)),
          minutes: 15));

      await pumpScreen(tester, repository, now: () => current);
      expect(find.text('45分'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('reading_delete_s1')));
      await tester.pumpAndSettle();

      expect(repository.length, 1);
      expect(find.byKey(AppKeys.readingSessionRow('s1')), findsNothing);
      expect(find.byKey(AppKeys.readingSessionRow('s2')), findsOneWidget);
      expect(find.text('15分'), findsNWidgets(2));
    });

    testWidgets('直近7日の日別リストは0日の日も含め7行表示する', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();
      await repository.add(session('s1',
          startedAt: base.subtract(const Duration(days: 2, hours: 1)),
          minutes: 40));

      await pumpScreen(tester, repository, now: () => current);

      // 7日分の行（進捗バー + 分数ラベル）
      // 統計カードと直近7日の日別行の両方に 40分 が現れる
      expect(find.text('40分'), findsNWidgets(2));
      expect(find.text('0分'), findsNWidgets(6));
    });

    testWidgets('手動追加ダイアログで分数を入力すると repository に追加される', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();

      await pumpScreen(tester, repository, now: () => current);

      await tester.tap(find.byKey(AppKeys.readingAddButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('reading_manual_title_field')), '新しい本');
      await tester.enterText(
          find.byKey(const Key('reading_manual_minutes_field')), '25');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 不変条件：画面の操作が repository に到達する
      expect(repository.length, 1);
      final saved = await repository.loadAll();
      expect(saved.first.bookTitle, '新しい本');
      expect(saved.first.durationMinutes, 25);
      // 再集計で統計に反映される（統計カードと日別行）
      expect(find.text('25分'), findsNWidgets(2));
    });

    testWidgets('手動追加で不正な分数はエラー表示のみで追加されない', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();

      await pumpScreen(tester, repository, now: () => current);

      await tester.tap(find.byKey(AppKeys.readingAddButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('reading_manual_minutes_field')), 'abc');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('読書時間は正の整数で入力してください'), findsOneWidget);
      expect(repository.length, 0);

      // 0 も不正扱い
      await tester.enterText(
          find.byKey(const Key('reading_manual_minutes_field')), '0');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repository.length, 0);
    });

    testWidgets('手動追加をキャンセルすると追加されない', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();

      await pumpScreen(tester, repository, now: () => current);

      await tester.tap(find.byKey(AppKeys.readingAddButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('reading_manual_minutes_field')), '30');
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(repository.length, 0);
    });

    testWidgets('タイマー: 開始→経過表示→停止→保存で repository に追加される', (tester) async {
      var current = base;
      final repository = InMemoryReadingSessionRepository();

      await pumpScreen(tester, repository, now: () => current);

      await tester.tap(find.byKey(AppKeys.readingStart));
      await tester.pump();

      // 時刻を 125 秒進めて 1 tick 分だけ pump（pumpAndSettle は使わない）
      current = base.add(const Duration(seconds: 125));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(AppKeys.readingElapsed), findsOneWidget);
      expect(find.text('02:05'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pump();

      // 確定 → 保存（2分）
      await tester.tap(find.byKey(AppKeys.readingStop));
      await tester.pumpAndSettle();

      expect(repository.length, 1);
      final saved = await repository.loadAll();
      expect(saved.first.durationMinutes, 2);
      // 保存後は統計へ反映（日別行は '2分'、統計も '2分'）
      expect(find.text('2分'), findsNWidgets(2));
    });
  });

  group('書庫 AppBar の導線ゲート', () {
    testWidgets('readingTimerButton を持つ', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(
            repository: FakeBookRepository([
              Book(id: 'b1', title: '本', author: '著者', isbn: 'isbn-1'),
            ]),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(AppKeys.readingTimerButton), findsOneWidget);
    });

    testWidgets('タップで読書時間画面へ遷移する', (tester) async {
      // flutter_tester は fake-async で実 IO（Hive のボックス opened）が
      // 完結しないため、試練ではインメモリ実装を差し込む。
      // 本配線の既定は HiveReadingSessionRepository。
      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(
            repository: FakeBookRepository([]),
            readingSessionRepositoryOverride:
                InMemoryReadingSessionRepository(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.readingTimerButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_reading_session')), findsOneWidget);
      expect(find.text('読書時間'), findsOneWidget);
    });
  });
}
