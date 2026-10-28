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
import 'package:book_review_app/features/loan/domain/loan_due_reminder_resync.dart';

/// trigger の呼出回数だけを数える偽の再計算窓口。
class _RecordingResync implements LoanDueReminderResync {
  int triggerCount = 0;

  @override
  Future<bool> trigger() async {
    triggerCount++;
    return true;
  }
}

/// trigger が呼ばれた時点で貸出が永続化済みかを確かめるための窓口。
class _ProbingResync implements LoanDueReminderResync {
  _ProbingResync(this.repository);

  final BookLoanRepository repository;
  List<BookLoan> seen = const [];

  @override
  Future<bool> trigger() async {
    seen = await repository.loadLoans();
    return true;
  }
}

class _MockBookRepository implements BookRepository {
  _MockBookRepository({this.books = const []});

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
  final now = DateTime.utc(2026, 9, 18, 12).toLocal();

  final book = Book(
    id: 'b1',
    title: '宇宙の本',
    author: '著者A',
    isbn: 'isbn-b1',
  );

  BookLoan activeLoan() => BookLoan(
        id: 'loan_active',
        bookId: 'b1',
        borrower: '田中',
        lentAt: now.subtract(const Duration(days: 10)),
        dueAt: now.add(const Duration(days: 3)),
      );

  Future<void> pumpDetail(
    WidgetTester tester, {
    required BookLoanRepository loanRepository,
    LoanDueReminderResync? reminderResync,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailScreen(
          book: book,
          bookRepository: _MockBookRepository(books: [book]),
          reviewRepository: _MockReviewRepository(),
          loanRepository: loanRepository,
          nowOverride: now,
          reminderResync: reminderResync,
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

  testWidgets('貸出を記録すると再計算が呼ばれ、その時点で貸出は永続化済み', (tester) async {
    final repository = InMemoryBookLoanRepository();
    final resync = _ProbingResync(repository);
    await pumpDetail(
      tester,
      loanRepository: repository,
      reminderResync: resync,
    );
    await scrollToLoanSection(tester);

    await tester.tap(find.byKey(AppKeys.loanLendButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.loanBorrowerField), '佐藤');
    await tester.tap(find.byKey(AppKeys.loanSaveButton));
    await tester.pumpAndSettle();

    // 再計算は保存後に呼ばれ、その時点で未返却の貸出が1件見えている
    expect(resync.seen, hasLength(1));
    expect(resync.seen.single.borrower, '佐藤');
  });

  testWidgets('返却すると再計算が呼ばれる', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([activeLoan()]);
    final resync = _RecordingResync();
    await pumpDetail(
      tester,
      loanRepository: repository,
      reminderResync: resync,
    );
    await scrollToLoanSection(tester);

    await tester.tap(find.byKey(AppKeys.loanReturnButton('loan_active')));
    await tester.pumpAndSettle();

    expect(resync.triggerCount, 1);
    final persisted = await repository.loadLoans();
    expect(persisted.single.isReturned, isTrue);
  });

  testWidgets('reminderResync 未注入でも従来どおり動作する（後方互換）', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await pumpDetail(tester, loanRepository: repository);
    await scrollToLoanSection(tester);

    await tester.tap(find.byKey(AppKeys.loanLendButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.loanBorrowerField), '鈴木');
    await tester.tap(find.byKey(AppKeys.loanSaveButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final persisted = await repository.loadLoans();
    expect(persisted, hasLength(1));
    expect(persisted.single.borrower, '鈴木');
  });
}
