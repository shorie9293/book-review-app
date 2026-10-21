import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/presentation/book_detail_screen.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';

/// テスト用モック: BookRepository（getBooks のみ実データを返す）
class _MockBookRepository implements BookRepository {
  final List<Book> books;
  _MockBookRepository({this.books = const []});

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

  // 本番導線は HiveLoanDueReminderRepository を注入するため、
  // 試練側で Hive の箱を用意する（未初期化だと openBox が
  // 非同期例外を zone へ漏らしテストが落ちる）。
  late Directory tmpDir;
  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('loan_wiring_');
    Hive.init(tmpDir.path);
    // 箱を先に開いておく（画面側の openBox が解決済み Future を返す）。
    await Hive.openBox<String>(HiveLoanDueReminderRepository.boxName);
  });
  tearDown(() async {
    await Hive.close();
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  final book = Book(
    id: 'b1',
    title: '宇宙の本',
    author: '著者A',
    isbn: 'isbn-b1',
  );

  /// 蔵書詳細を pump し、「貸出中一覧を開く」で貸出管理画面へ遷移する。
  ///
  /// 本番導線（[BookDetailScreen._openLoanManagement]）が返却期限リマインダーの
  /// 実装を自分で注入することを、ユーザー操作だけで検証する。
  Future<void> openLoanManagement(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final loanRepository = InMemoryBookLoanRepository();
    await loanRepository.saveLoans([
      BookLoan(
        id: 'loan_active',
        bookId: 'b1',
        borrower: '田中',
        lentAt: now.subtract(const Duration(days: 10)),
        dueAt: now.add(const Duration(days: 3)),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailScreen(
          book: book,
          bookRepository: _MockBookRepository(books: [book]),
          reviewRepository: _MockReviewRepository(),
          loanRepository: loanRepository,
          nowOverride: now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(AppKeys.loanEntryButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.loanEntryButton));
    await tester.pumpAndSettle();
  }

  testWidgets('蔵書詳細 → 貸出管理の実導線で返却期限の通知セクションが出る',
      (tester) async {
    await openLoanManagement(tester);

    // 貸出管理画面へ遷移している（本番経路）
    expect(find.byKey(AppKeys.loanManagementScreen), findsOneWidget);
    // 両依存が実装注入されているため通知セクションが描画される
    expect(find.byKey(AppKeys.loanDueReminderSection), findsOneWidget);
    expect(find.byKey(AppKeys.loanDueReminderSwitch), findsOneWidget);
    expect(find.text('返却期限の通知'), findsOneWidget);
  });

  testWidgets('通知セクションは書名ローダの書名を貸出一覧に反映する', (tester) async {
    await openLoanManagement(tester);

    // bookTitleLoader が BookRepository.getBooks の書名を引けている
    expect(find.textContaining('宇宙の本'), findsWidgets);
  });
}
