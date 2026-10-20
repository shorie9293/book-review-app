import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/loan/domain/book_loan_service.dart';

/// テスト用モック: BookRepository
class MockBookRepository implements BookRepository {
  final List<Book> books;
  MockBookRepository({this.books = const []});

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

/// テスト用モック: ReviewRepository
class MockReviewRepository implements ReviewRepository {
  final List<Review> reviews;
  MockReviewRepository({this.reviews = const []});

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => reviews;

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

void main() {
  final now = DateTime.utc(2026, 9, 18, 12).toLocal();
  DateTime day(int offset) => DateTime.utc(2026, 9, 18 + offset, 12).toLocal();

  final book = Book(
    id: 'b1',
    title: '宇宙の本',
    author: '著者A',
    isbn: 'isbn-b1',
  );

  BookLoan activeLoan({DateTime? dueAt}) => BookLoan(
        id: 'loan_active',
        bookId: 'b1',
        borrower: '田中',
        lentAt: day(-10),
        dueAt: dueAt ?? day(3),
      );

  Future<void> pumpDetail(
    WidgetTester tester, {
    BookLoanRepository? loanRepository,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailScreen(
          book: book,
          bookRepository: MockBookRepository(books: [book]),
          reviewRepository: MockReviewRepository(),
          loanRepository: loanRepository,
          nowOverride: now,
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

  testWidgets('loanRepository を渡すと貸出セクションが出る', (tester) async {
    await pumpDetail(
      tester,
      loanRepository: InMemoryBookLoanRepository(),
    );
    await scrollToLoanSection(tester);

    expect(find.byKey(AppKeys.loanDetailSection), findsOneWidget);
    expect(find.byKey(AppKeys.loanLendButton), findsOneWidget);
    expect(find.byKey(AppKeys.loanEntryButton), findsOneWidget);
  });

  testWidgets('loanRepository を渡さないと貸出セクションは出ない（既存互換）', (tester) async {
    await pumpDetail(tester);

    expect(find.byKey(AppKeys.loanDetailSection), findsNothing);
    expect(find.byKey(AppKeys.loanLendButton), findsNothing);
    expect(find.byKey(AppKeys.loanEntryButton), findsNothing);
    // 既存セクションは従来どおり
    expect(find.text('サマリー'), findsOneWidget);
  });

  testWidgets('未返却の貸出があれば借り手と期限・返却ボタンを出す', (tester) async {
    final loan = activeLoan(dueAt: day(-2));
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([loan]);

    await pumpDetail(tester, loanRepository: repository);
    await scrollToLoanSection(tester);

    final label = find.byKey(AppKeys.loanDetailStatusLabel);
    expect(label, findsOneWidget);
    final text = tester.widget<Text>(label).data!;
    expect(text, contains('田中'));
    expect(text, contains(BookLoanService.dueLabel(loan, now: now)));
    expect(find.byKey(AppKeys.loanReturnButton('loan_active')), findsOneWidget);
    expect(find.byKey(AppKeys.loanLendButton), findsNothing);
  });

  testWidgets('「貸出を記録」で repository に永続化され表示が変わる', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await pumpDetail(tester, loanRepository: repository);
    await scrollToLoanSection(tester);

    await tester.tap(find.byKey(AppKeys.loanLendButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AppKeys.loanBorrowerField), '佐藤');
    await tester.tap(find.byKey(AppKeys.loanSaveButton));
    await tester.pumpAndSettle();

    final persisted = await repository.loadLoans();
    expect(persisted, hasLength(1));
    expect(persisted.single.borrower, '佐藤');
    expect(persisted.single.bookId, 'b1');
    expect(persisted.single.lentAt, now);

    await tester.pumpAndSettle();
    final label = find.byKey(AppKeys.loanDetailStatusLabel);
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).data!, contains('佐藤'));
  });

  testWidgets('返却ボタンで repository の貸出が返却済になる', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([activeLoan()]);
    await pumpDetail(tester, loanRepository: repository);
    await scrollToLoanSection(tester);

    await tester.tap(find.byKey(AppKeys.loanReturnButton('loan_active')));
    await tester.pumpAndSettle();

    final persisted = await repository.loadLoans();
    expect(persisted.single.isReturned, isTrue);
    expect(persisted.single.returnedAt, now);
    // 未返却が無くなったので記録導線に戻る
    expect(find.byKey(AppKeys.loanLendButton), findsOneWidget);
  });

  testWidgets('「貸出中一覧を開く」で貸出管理画面へ遷移する', (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([activeLoan()]);
    await pumpDetail(tester, loanRepository: repository);
    await scrollToLoanSection(tester);

    await tester.tap(find.byKey(AppKeys.loanEntryButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.loanManagementScreen), findsOneWidget);
    expect(find.byKey(AppKeys.loanRow('loan_active')), findsOneWidget);
  });

  testWidgets('本棚は loanRepository を蔵書詳細へ引き渡す', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([activeLoan()]);

    await tester.pumpWidget(
      MaterialApp(
        home: BookshelfScreen(
          repository: MockBookRepository(books: [book]),
          initialBooks: [book],
          reviewRepository: MockReviewRepository(),
          loanRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('宇宙の本').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(AppKeys.loanDetailSection),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.loanDetailSection), findsOneWidget);
    expect(find.byKey(AppKeys.loanDetailStatusLabel), findsOneWidget);
  });
}
