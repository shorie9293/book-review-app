import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/loan/presentation/loan_management_screen.dart';

/// 親探針用モック: BookRepository
class _FakeBookRepository implements BookRepository {
  final List<Book> books;
  _FakeBookRepository(this.books);

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

/// 親探針用モック: ReviewRepository
class _FakeReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async => const [];

  @override
  Future<void> addReview(Review review) async {}

  @override
  Future<void> updateReview(Review review) async {}

  @override
  Future<void> deleteReview(String id) async {}
}

/// 親探針（合成の不変条件）:
/// 眷属は画面・リポジトリ・サービスを個別にしか撃たない。
/// ここでは「詳細画面での操作 → 永続化 → 別画面での観測」という
/// 画面をまたぐ合成だけを撃ち、実バグが無いことを確証する。
void main() {
  final now = DateTime.utc(2026, 9, 18, 12).toLocal();
  DateTime day(int offset) => DateTime.utc(2026, 9, 18 + offset, 12).toLocal();

  final book = Book(
    id: 'b1',
    title: '宇宙の本',
    author: '著者A',
    isbn: 'isbn-b1',
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    InMemoryBookLoanRepository repository, {
    DateTime? nowOverride,
  }) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailScreen(
          book: book,
          bookRepository: _FakeBookRepository([book]),
          reviewRepository: _FakeReviewRepository(),
          loanRepository: repository,
          nowOverride: nowOverride ?? now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('探針1: 詳細で返却 → 同じリポジトリを見る一覧画面で履歴へ移る（画面をまたぐ合成）',
      (tester) async {
    final repository = InMemoryBookLoanRepository();
    await repository.saveLoans([
      BookLoan(
        id: 'loan_active',
        bookId: 'b1',
        borrower: '田中',
        lentAt: day(-10),
        dueAt: day(3),
      ),
    ]);

    await pumpDetail(tester, repository);

    // 詳細に借り手と返却ボタンが出ている
    expect(find.textContaining('田中'), findsWidgets);
    final returnButton = find.byKey(AppKeys.loanReturnButton('loan_active'));
    expect(returnButton, findsOneWidget);

    await tester.tap(returnButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 永続化層に返却が到達している（state 更新だけで終わっていない）
    final saved = await repository.loadLoans();
    expect(saved.length, 1);
    expect(saved.single.isReturned, isTrue);

    // 同じリポジトリを別画面（一覧）で観測: 貸出中から消え履歴に現れる
    await tester.pumpWidget(
      MaterialApp(
        home: LoanManagementScreen(repository: repository, nowOverride: now),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('貸出中 0冊'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.loanFilterReturned));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(AppKeys.loanRow('loan_active')), findsOneWidget);
  });

  testWidgets('探針2: 詳細で貸出を記録 → 永続化され、同じ画面の表示が即座に借り手へ変わる',
      (tester) async {
    final repository = InMemoryBookLoanRepository();
    await pumpDetail(tester, repository);

    // 貸出が無いので「貸出を記録」が出る
    final lendButton = find.byKey(AppKeys.loanLendButton);
    expect(lendButton, findsOneWidget);

    await tester.tap(lendButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AppKeys.loanBorrowerField), '佐藤');
    await tester.tap(find.byKey(AppKeys.loanSaveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 永続化に到達
    final saved = await repository.loadLoans();
    expect(saved.length, 1);
    expect(saved.single.bookId, 'b1');
    expect(saved.single.borrower, '佐藤');

    // 同一画面が再読込され、表示が「貸出を記録」から借り手表示へ変わる
    expect(find.byKey(AppKeys.loanLendButton), findsNothing);
    expect(find.textContaining('佐藤'), findsWidgets);
    expect(find.byKey(AppKeys.loanDetailStatusLabel), findsOneWidget);
  });
}
