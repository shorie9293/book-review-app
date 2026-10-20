import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';

void main() {
  DateTime d(int y, int m, int day, [int h = 0]) =>
      DateTime.utc(y, m, day, h).toLocal();

  BookLoan loan({
    required String id,
    String bookId = 'b1',
    DateTime? returnedAt,
  }) =>
      BookLoan(
        id: id,
        bookId: bookId,
        borrower: '山田太郎',
        lentAt: d(2026, 10, 1),
        dueAt: d(2026, 10, 20),
        returnedAt: returnedAt,
      );

  group('InMemoryBookLoanRepository', () {
    late InMemoryBookLoanRepository repo;

    setUp(() {
      repo = InMemoryBookLoanRepository();
    });

    test('初期状態は空', () async {
      expect(await repo.loadLoans(), isEmpty);
    });

    test('保存内容を保持する', () async {
      final loans = [loan(id: 'a'), loan(id: 'b', bookId: 'b2')];
      await repo.saveLoans(loans);
      expect(await repo.loadLoans(), loans);
    });

    test('上書き保存で以前の内容が消える', () async {
      await repo.saveLoans([loan(id: 'a')]);
      await repo.saveLoans([loan(id: 'c', bookId: 'b3')]);
      expect((await repo.loadLoans()).map((e) => e.id), ['c']);
    });

    test('空リスト保存で空になる', () async {
      await repo.saveLoans([loan(id: 'a')]);
      await repo.saveLoans([]);
      expect(await repo.loadLoans(), isEmpty);
    });

    test('返却済もそのまま保持する', () async {
      final l = loan(id: 'a', returnedAt: d(2026, 10, 9));
      await repo.saveLoans([l]);
      expect((await repo.loadLoans()).single.isReturned, isTrue);
    });
  });

  group('NoopBookLoanRepository', () {
    late NoopBookLoanRepository repo;

    setUp(() {
      repo = NoopBookLoanRepository();
    });

    test('常に空を返す', () async {
      expect(await repo.loadLoans(), isEmpty);
    });

    test('保存しても沈黙して空のまま', () async {
      await repo.saveLoans([loan(id: 'a')]);
      expect(await repo.loadLoans(), isEmpty);
    });

    test('空リスト保存も例外なし', () async {
      await repo.saveLoans([]);
      expect(await repo.loadLoans(), isEmpty);
    });
  });
}
