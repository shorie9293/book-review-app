import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/import/domain/isbn_validator.dart';

void main() {
  group('IsbnValidator.normalize', () {
    test('ハイフンと空白を除去する', () {
      expect(IsbnValidator.normalize('978-4-7741-8907-9'), '9784774189079');
      expect(IsbnValidator.normalize(' 978 4123 456784 '), '9784123456784');
    });

    test('全角数字を半角に揃える', () {
      expect(IsbnValidator.normalize('９７８４７７４１８９０７９'), '9784774189079');
    });

    test('小文字 x のチェックディジットを X に揃える', () {
      expect(IsbnValidator.normalize('080442957x'), '080442957X');
    });
  });

  group('IsbnValidator.isValid', () {
    test('妥当なISBN-13を受け入れる', () {
      expect(IsbnValidator.isValid('9784774189079'), isTrue);
      expect(IsbnValidator.isValid('978-4-7741-8907-9'), isTrue);
      expect(IsbnValidator.isValid('9784123456784'), isTrue);
    });

    test('チェックディジット不正なISBN-13を拒否する', () {
      expect(IsbnValidator.isValid('9784774189078'), isFalse);
    });

    test('妥当なISBN-10を受け入れ、X桁も扱える', () {
      expect(IsbnValidator.isValid('4123456782'), isTrue);
      expect(IsbnValidator.isValid('080442957X'), isTrue);
    });

    test('チェックディジット不正なISBN-10を拒否する', () {
      expect(IsbnValidator.isValid('4123456783'), isFalse);
    });

    test('桁数不足・超過を拒否する', () {
      expect(IsbnValidator.isValid('123'), isFalse);
      expect(IsbnValidator.isValid('97847741890791'), isFalse);
      expect(IsbnValidator.isValid(''), isFalse);
    });

    test('数字以外の文字を含む入力を拒否する', () {
      expect(IsbnValidator.isValid('abc9784774189079'), isFalse);
      expect(IsbnValidator.isValid('ISBN:9784774189079'), isFalse);
    });
  });
}
