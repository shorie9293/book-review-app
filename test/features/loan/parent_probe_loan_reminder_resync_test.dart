import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_coordinator.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_resync.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';

/// 親探針: 「配線が実際に通知スケジューラまで届くか」を合成で撃つ。
///
/// 子の試練は trigger の呼出回数しか見ないため、
/// ・本文に書名が入るか
/// ・返却で登録が解除されるか
/// ・冪等か（固定IDで1件に収まるか）
/// は親が確かめる。
class _FakeSettingsRepository implements LoanDueReminderRepository {
  _FakeSettingsRepository(this._settings);

  LoanDueReminderSettings _settings;

  @override
  Future<LoanDueReminderSettings> load() async => _settings;

  @override
  Future<void> save(LoanDueReminderSettings s) async => _settings = s;
}

/// 固定IDで上書きする実装を模す（本番 _loanDueBaseId と同じ意味論）。
class _FixedIdScheduler implements LoanDueReminderScheduler {
  static const int id = 300;

  int cancelCount = 0;
  int scheduleCount = 0;
  final Map<int, ({String body, int hour, int minute})> registered = {};

  @override
  Future<void> schedule({
    required String body,
    required int hour,
    required int minute,
  }) async {
    scheduleCount++;
    registered[id] = (body: body, hour: hour, minute: minute);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    registered.clear();
  }
}

class _MockBookRepository implements BookRepository {
  _MockBookRepository(this.books);

  final List<Book> books;

  @override
  Future<List<Book>> getBooks() async => books;

  @override
  Future<Book?> getBookById(String id) async {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async {}

  @override
  Future<void> updateBook(Book book) async {}

  @override
  Future<void> removeBook(String id) async {}
}

class _MockReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => const [];

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

void main() {
  final now = DateTime(2026, 9, 18, 12);

  const book = Book(
    id: 'b1',
    title: '宇宙の本',
    author: '著者A',
    isbn: 'isbn-b1',
  );
  const otherBook = Book(
    id: 'b2',
    title: '古い本',
    author: '著者B',
    isbn: 'isbn-b2',
  );

  /// b1 の返却期限切れ貸出。
  BookLoan overdueLoanOfB1() => BookLoan(
        id: 'loan_b1',
        bookId: 'b1',
        borrower: '田中',
        lentAt: now.subtract(const Duration(days: 30)),
        dueAt: now.subtract(const Duration(days: 5)),
      );

  /// b2 の返却期限切れ貸出（別の本＝追加操作の影響を受けない対照）。
  BookLoan overdueLoanOfB2() => BookLoan(
        id: 'loan_b2',
        bookId: 'b2',
        borrower: '佐々木',
        lentAt: now.subtract(const Duration(days: 20)),
        dueAt: now.subtract(const Duration(days: 2)),
      );

  LoanDueReminderResync buildResync({
    required BookLoanRepository loans,
    required LoanDueReminderRepository settings,
    required _FixedIdScheduler scheduler,
  }) {
    return LoanDueReminderResync(
      coordinator: LoanDueReminderCoordinator(
        settingsRepository: settings,
        loanRepository: loans,
        scheduler: scheduler,
        clock: () => now,
        bookTitleLoader: () async => {
          book.id: book.title,
          otherBook.id: otherBook.title,
        },
      ),
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required BookLoanRepository loanRepository,
    required LoanDueReminderResync resync,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailScreen(
          book: book,
          bookRepository: _MockBookRepository([book, otherBook]),
          reviewRepository: _MockReviewRepository(),
          loanRepository: loanRepository,
          nowOverride: now,
          reminderResync: resync,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToLoanSection(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(AppKeys.loanDetailSection),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  test('探針1: 再計算で書名入りの通知が1件だけ登録され、連打しても増えない（冪等）',
      () async {
    final loans = InMemoryBookLoanRepository();
    await loans.saveLoans([overdueLoanOfB1()]);
    final settings = _FakeSettingsRepository(
      LoanDueReminderSettings(enabled: true, hour: 9, minute: 0),
    );
    final scheduler = _FixedIdScheduler();
    final resync = buildResync(
      loans: loans,
      settings: settings,
      scheduler: scheduler,
    );

    expect(await resync.trigger(), isTrue);
    expect(scheduler.scheduleCount, 1);
    expect(scheduler.registered, hasLength(1));
    final body = scheduler.registered.values.single.body;
    expect(body, contains('宇宙の本'));
    expect(body, contains('1件'));

    // 起動→追加→返却と何度呼ばれても、固定IDの登録は1件のまま。
    await resync.trigger();
    await resync.trigger();
    expect(scheduler.registered, hasLength(1));
    expect(scheduler.cancelCount, 0);
  });

  testWidgets('探針3: 返却のUI操作で通知本文が実際に減る（画面→repository→schedulerの合成）',
      (tester) async {
    final loans = InMemoryBookLoanRepository();
    await loans.saveLoans([overdueLoanOfB1(), overdueLoanOfB2()]);
    final settings = _FakeSettingsRepository(
      LoanDueReminderSettings(enabled: true, hour: 9, minute: 0),
    );
    final scheduler = _FixedIdScheduler();
    final resync = buildResync(
      loans: loans,
      settings: settings,
      scheduler: scheduler,
    );

    await resync.trigger();
    expect(scheduler.registered.values.single.body, contains('2件'));

    await pumpDetail(tester, loanRepository: loans, resync: resync);
    await scrollToLoanSection(tester);
    await tester.tap(find.byKey(AppKeys.loanReturnButton('loan_b1')));
    await tester.pumpAndSettle();

    // 返却後は b2 の1件だけが残る＝超過アラートが残り続けない。
    expect(scheduler.registered.values.single.body, contains('古い本'));
    expect(scheduler.registered.values.single.body, contains('1件'));
    expect(scheduler.registered.values.single.body, isNot(contains('宇宙の本')));
  });

  testWidgets('探針4: 貸出の追加（期限なし）でも再計算が走り、既存の別本アラートは保持される',
      (tester) async {
    final loans = InMemoryBookLoanRepository();
    await loans.saveLoans([overdueLoanOfB2()]);
    final settings = _FakeSettingsRepository(
      LoanDueReminderSettings(enabled: true, hour: 9, minute: 0),
    );
    final scheduler = _FixedIdScheduler();
    final resync = buildResync(
      loans: loans,
      settings: settings,
      scheduler: scheduler,
    );

    await pumpDetail(tester, loanRepository: loans, resync: resync);
    await scrollToLoanSection(tester);

    final before = scheduler.scheduleCount + scheduler.cancelCount;

    await tester.tap(find.byKey(AppKeys.loanLendButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.loanBorrowerField), '新任');
    await tester.tap(find.byKey(AppKeys.loanSaveButton));
    await tester.pumpAndSettle();

    // 追加操作でも再計算が走る（呼ばれていないなら before のまま）。
    expect(scheduler.scheduleCount + scheduler.cancelCount, greaterThan(before));
    // 期限なしの追加はアラートを増やさず、既存の別本アラートは消えない。
    expect(scheduler.registered, hasLength(1));
    expect(scheduler.registered.values.single.body, contains('古い本'));
  });

  test('探針5: 設定OFFなら再計算は登録せず解除する（OFF経路の解除漏れ防止）', () async {
    final loans = InMemoryBookLoanRepository();
    await loans.saveLoans([overdueLoanOfB1()]);
    final settings = _FakeSettingsRepository(
      LoanDueReminderSettings(enabled: false),
    );
    final scheduler = _FixedIdScheduler();
    final resync = buildResync(
      loans: loans,
      settings: settings,
      scheduler: scheduler,
    );

    await resync.trigger();
    expect(scheduler.scheduleCount, 0);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.registered, isEmpty);
  });
}
