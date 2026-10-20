import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';

void main() {
  DateTime d(int y, int m, int day, [int h = 0]) =>
      DateTime.utc(y, m, day, h).toLocal();

  BookLoan loan({
    required String id,
    String bookId = 'b1',
    String borrower = '山田太郎',
    DateTime? dueAt,
    DateTime? returnedAt,
  }) =>
      BookLoan(
        id: id,
        bookId: bookId,
        borrower: borrower,
        lentAt: d(2026, 10, 1),
        dueAt: dueAt,
        returnedAt: returnedAt,
      );

  group('HiveBookLoanRepository', () {
    late HiveBookLoanRepository repo;
    late String tempPath;

    setUpAll(() async {
      tempPath = Directory.systemTemp
          .createTempSync('hive_book_loan_test_')
          .path;
      Hive.init(tempPath);
    });

    setUp(() async {
      const boxName = 'book_loans_test';
      if (Hive.isBoxOpen(boxName)) {
        await Hive.deleteBoxFromDisk(boxName);
      } else {
        await Hive.deleteBoxFromDisk(boxName);
      }
      repo = HiveBookLoanRepository();
      await repo.init(boxName: boxName);
    });

    tearDown(() async {
      await repo.clear();
      await repo.close();
    });

    test('defaultBoxName は book_loans', () {
      expect(HiveBookLoanRepository.defaultBoxName, 'book_loans');
    });

    test('保存→読み込みで値等価', () async {
      final loans = [
        loan(id: 'a', bookId: 'b1', dueAt: d(2026, 10, 20)),
        loan(id: 'b', bookId: 'b2', returnedAt: d(2026, 10, 5)),
      ];
      await repo.saveLoans(loans);
      final loaded = await repo.loadLoans();
      expect(loaded, loans);
    });

    test('saveLoans は既存内容を全置換する', () async {
      await repo.saveLoans([loan(id: 'a'), loan(id: 'b', bookId: 'b2')]);
      await repo.saveLoans([loan(id: 'c', bookId: 'b3')]);
      final loaded = await repo.loadLoans();
      expect(loaded.map((e) => e.id), ['c']);
    });

    test('空リスト保存で空になる', () async {
      await repo.saveLoans([loan(id: 'a')]);
      await repo.saveLoans([]);
      expect(await repo.loadLoans(), isEmpty);
    });

    test('初期状態は空', () async {
      expect(await repo.loadLoans(), isEmpty);
    });

    test('破損エントリは読み飛ばして正常分を返す', () async {
      final box = Hive.box<String>('book_loans_test');
      await box.put('good', '{"id":"a","bookId":"b1","borrower":"x",'
          '"lentAt":"2026-10-01T00:00:00.000Z","dueAt":null,'
          '"returnedAt":null}');
      await box.put('broken', '{not json');
      await box.put('wrongshape', '[1,2,3]');
      final loaded = await repo.loadLoans();
      expect(loaded.length, 1);
      expect(loaded.single.id, 'a');
    });

    test('キーは loan.id で保存される', () async {
      await repo.saveLoans([loan(id: 'key-1', bookId: 'b9')]);
      final box = Hive.box<String>('book_loans_test');
      expect(box.keys, contains('key-1'));
      expect(box.get('key-1'), contains('b9'));
    });

    test('clear で全消去', () async {
      await repo.saveLoans([loan(id: 'a')]);
      await repo.clear();
      expect(await repo.loadLoans(), isEmpty);
    });
  });
}
