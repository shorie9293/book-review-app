import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/crossapp/domain/cross_app_link_code.dart';

void main() {
  group('linkCodeOf', () {
    test('userId の先頭8文字を返す', () {
      expect(
        linkCodeOf('3f2a9c1b-7d4e-4a11-9b02-abcdefabcdef'),
        '3f2a9c1b',
      );
    });

    test('8文字未満なら全体を返す', () {
      expect(linkCodeOf('abc123'), 'abc123');
    });

    test('空文字なら空文字', () {
      expect(linkCodeOf(''), '');
    });

    test('前後の空白は trim してから切り出す', () {
      expect(linkCodeOf('  1234567890  '), '12345678');
      expect(linkCodeOf('   '), '');
    });

    test('ちょうど8文字ならそのまま', () {
      expect(linkCodeOf('ABCD2345'), 'ABCD2345');
    });
  });

  group('isValidLinkCode', () {
    test('8文字の英数字だけが有効', () {
      expect(isValidLinkCode('abcd1234'), isTrue);
      expect(isValidLinkCode('ABCD1234'), isTrue);
      expect(isValidLinkCode('00000000'), isTrue);
    });

    test('長さ違いは無効', () {
      expect(isValidLinkCode('abcd123'), isFalse);
      expect(isValidLinkCode('abcd12345'), isFalse);
      expect(isValidLinkCode(''), isFalse);
    });

    test('英数字以外を含むと無効', () {
      expect(isValidLinkCode('abcd-123'), isFalse);
      expect(isValidLinkCode('abcd 123'), isFalse);
      expect(isValidLinkCode('abcd_123'), isFalse);
      expect(isValidLinkCode('あいうえおかきく'), isFalse);
    });

    test('trim はしない（8文字ちょうどのみ）', () {
      expect(isValidLinkCode(' abcd123'), isFalse);
    });
  });
}
