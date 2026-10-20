import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_loan.dart';

void main() {
  DateTime d(int y, int m, int day, [int h = 0]) =>
      DateTime.utc(y, m, day, h).toLocal();

  BookLoan loan({
    String id = 'l1',
    String bookId = 'b1',
    String borrower = '山田太郎',
    DateTime? lentAt,
    DateTime? dueAt,
    DateTime? returnedAt,
  }) =>
      BookLoan(
        id: id,
        bookId: bookId,
        borrower: borrower,
        lentAt: lentAt ?? d(2026, 10, 1),
        dueAt: dueAt,
        returnedAt: returnedAt,
      );

  group('BookLoan コンストラクタ検証', () {
    test('正常な貸出を生成できる', () {
      final l = loan(dueAt: d(2026, 10, 20));
      expect(l.id, 'l1');
      expect(l.bookId, 'b1');
      expect(l.borrower, '山田太郎');
      expect(l.lentAt, d(2026, 10, 1));
      expect(l.dueAt, d(2026, 10, 20));
      expect(l.returnedAt, isNull);
    });

    test('空文字 id は ArgumentError', () {
      expect(() => loan(id: ''), throwsArgumentError);
    });

    test('空白のみ bookId は ArgumentError', () {
      expect(() => loan(bookId: '   '), throwsArgumentError);
    });

    test('空白のみ borrower は ArgumentError', () {
      expect(() => loan(borrower: '\t '), throwsArgumentError);
    });

    test('任意項目 dueAt / returnedAt は省略できる', () {
      final l = loan();
      expect(l.dueAt, isNull);
      expect(l.returnedAt, isNull);
    });
  });

  group('BookLoan isReturned', () {
    test('returnedAt が null なら false', () {
      expect(loan().isReturned, isFalse);
    });

    test('returnedAt が非 null なら true', () {
      expect(loan(returnedAt: d(2026, 10, 10)).isReturned, isTrue);
    });
  });

  group('BookLoan copyWith', () {
    test('borrower を変更できる', () {
      final l = loan().copyWith(borrower: '佐藤花子');
      expect(l.borrower, '佐藤花子');
      expect(l.id, 'l1');
    });

    test('lentAt を変更できる', () {
      final l = loan().copyWith(lentAt: d(2026, 10, 5));
      expect(l.lentAt, d(2026, 10, 5));
    });

    test('dueAt を設定できる', () {
      final l = loan().copyWith(dueAt: d(2026, 10, 30));
      expect(l.dueAt, d(2026, 10, 30));
    });

    test('clearDueAt で dueAt を null にできる', () {
      final l = loan(dueAt: d(2026, 10, 30)).copyWith(clearDueAt: true);
      expect(l.dueAt, isNull);
    });

    test('returnedAt を設定できる', () {
      final l = loan().copyWith(returnedAt: d(2026, 10, 12));
      expect(l.returnedAt, d(2026, 10, 12));
      expect(l.isReturned, isTrue);
    });

    test('clearReturnedAt で返却を取り消せる', () {
      final l = loan(returnedAt: d(2026, 10, 12))
          .copyWith(clearReturnedAt: true);
      expect(l.returnedAt, isNull);
      expect(l.isReturned, isFalse);
    });
  });

  group('BookLoan JSON往復', () {
    test('全フィールドありで値等価', () {
      final l = loan(
        dueAt: d(2026, 10, 20),
        returnedAt: d(2026, 10, 18),
      );
      final restored = BookLoan.fromJson(l.toJson());
      expect(restored, l);
    });

    test('任意項目 null でも往復できる', () {
      final l = loan();
      final restored = BookLoan.fromJson(l.toJson());
      expect(restored, l);
      expect(restored.dueAt, isNull);
      expect(restored.returnedAt, isNull);
    });

    test('toJson は DateTime を ISO8601 文字列で返す', () {
      final json = loan(dueAt: d(2026, 10, 20)).toJson();
      expect(json['lentAt'], isA<String>());
      expect(DateTime.parse(json['lentAt'] as String), d(2026, 10, 1));
      expect(json['dueAt'], d(2026, 10, 20).toIso8601String());
      expect(json['returnedAt'], isNull);
    });

    test('必須キー id 欠落は FormatException', () {
      expect(
        () => BookLoan.fromJson({
          'bookId': 'b1',
          'borrower': 'x',
          'lentAt': d(2026, 10, 1).toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test('必須キー lentAt 型不正は FormatException', () {
      expect(
        () => BookLoan.fromJson({
          'id': 'l1',
          'bookId': 'b1',
          'borrower': 'x',
          'lentAt': 12345,
        }),
        throwsFormatException,
      );
    });

    test('borrower 欠落は FormatException', () {
      expect(
        () => BookLoan.fromJson({
          'id': 'l1',
          'bookId': 'b1',
          'lentAt': d(2026, 10, 1).toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test('任意キー dueAt が不正文字列なら FormatException', () {
      expect(
        () => BookLoan.fromJson({
          'id': 'l1',
          'bookId': 'b1',
          'borrower': 'x',
          'lentAt': d(2026, 10, 1).toIso8601String(),
          'dueAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });

  group('BookLoan 値等価と toString', () {
    test('全フィールド同値なら == / 同一 hashCode', () {
      final a = loan(dueAt: d(2026, 10, 20));
      final b = loan(dueAt: d(2026, 10, 20));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('borrower が違えば非等価', () {
      expect(loan(borrower: 'A') == loan(borrower: 'B'), isFalse);
    });

    test('returnedAt が違えば非等価', () {
      expect(
        loan(returnedAt: d(2026, 10, 10)) == loan(returnedAt: d(2026, 10, 11)),
        isFalse,
      );
    });

    test('toString に id と borrower を含む', () {
      final s = loan().toString();
      expect(s, contains('l1'));
      expect(s, contains('山田太郎'));
    });
  });
}
