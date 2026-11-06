import 'package:book_review_app/core/text/japanese_collation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('titleSortKey', () {
    test('ひらがなとカタカナを同一キーに畳む', () {
      expect(titleSortKey('あ'), titleSortKey('ア'));
      expect(titleSortKey('ん'), titleSortKey('ン'));
      expect(titleSortKey('がっこう'), titleSortKey('ガッコウ'));
    });

    test('半角カナを全角カナに畳む', () {
      expect(titleSortKey('ｱｲｳ'), titleSortKey('アイウ'));
      expect(titleSortKey('ｶﾞｯｺｳ'), titleSortKey('ガッコウ'));
    });

    test('前後の空白を除去する（半角・全角とも）', () {
      expect(titleSortKey('  あ  '), titleSortKey('あ'));
      expect(titleSortKey('\u3000あ\u3000'), titleSortKey('あ'));
      expect(titleSortKey('  '), '');
    });

    test('全角空白を半角空白に正規化する（内部空白）', () {
      expect(titleSortKey('あ\u3000い'), 'ア イ');
      expect(titleSortKey('あ い'), titleSortKey('あ\u3000い'));
    });

    test('冪等である', () {
      const samples = ['あ', 'ア イ', '  ｶﾞｯｺｳ  ', '漢字 タイトル', '', '\u3000ん\u3000'];
      for (final s in samples) {
        final once = titleSortKey(s);
        expect(titleSortKey(once), once, reason: 'sample: $s');
      }
    });
  });

  group('titleGroup', () {
    test('かな（ひらがな・カタカナ・長音・半角カナ）は 0', () {
      expect(titleGroup('あ'), 0);
      expect(titleGroup('ア'), 0);
      expect(titleGroup('ー'), 0);
      expect(titleGroup('ｱ'), 0);
      expect(titleGroup('ん'), 0);
    });

    test('漢字・英字・数字・記号・空文字は 1', () {
      expect(titleGroup('漢'), 1);
      expect(titleGroup('A'), 1);
      expect(titleGroup('1'), 1);
      expect(titleGroup('「'), 1);
      expect(titleGroup(''), 1);
    });

    test('前後空白は無視して判定する', () {
      expect(titleGroup('  あ'), 0);
      expect(titleGroup('  漢'), 1);
    });
  });

  group('compareJapaneseTitles', () {
    test('かな同士は あ→ん の順になる', () {
      final sorted = ['ん', 'あ', 'い', 'う'].toList()
        ..sort(compareJapaneseTitles);
      expect(sorted, ['あ', 'い', 'う', 'ん']);
    });

    test('ひらがなとカタカナが混在してもかな順になる', () {
      final sorted = ['ん', 'イ', 'あ', 'ウ'].toList()
        ..sort(compareJapaneseTitles);
      expect(sorted, ['あ', 'イ', 'ウ', 'ん']);
    });

    test('ひらがな同士・カタカナ同士の同字は 0（表記ゆれは等価）', () {
      expect(compareJapaneseTitles('あ', 'ア'), 0);
      expect(compareJapaneseTitles('ｱ', 'ア'), 0);
    });

    test('かなは漢字より前に来る', () {
      expect(compareJapaneseTitles('ん', '漢'), lessThan(0));
      expect(compareJapaneseTitles('漢', 'ん'), greaterThan(0));
    });

    test('漢字同士・英字同士はコードポイント順', () {
      expect(compareJapaneseTitles('亜', '漢'), lessThan(0));
      expect(compareJapaneseTitles('a', 'b'), lessThan(0));
    });

    test('空文字はかなの後・漢字等の先頭に来る', () {
      expect(compareJapaneseTitles('', 'ん'), greaterThan(0));
      expect(compareJapaneseTitles('', 'あ'), greaterThan(0));
      expect(compareJapaneseTitles('', '漢'), lessThan(0));
      expect(compareJapaneseTitles('', 'A'), lessThan(0));
      expect(compareJapaneseTitles('', ''), 0);
    });

    test('符号反転対称性を持つ', () {
      const pairs = [
        ['あ', 'ん'],
        ['あ', 'ア'],
        ['ん', '漢'],
        ['漢', '英'],
        ['', 'あ'],
        ['', '漢'],
        ['ｱ', 'ん'],
        ['同じ', '同じ'],
      ];
      for (final pair in pairs) {
        final ab = compareJapaneseTitles(pair[0], pair[1]);
        final ba = compareJapaneseTitles(pair[1], pair[0]);
        expect(ab.sign, -ba.sign, reason: 'pair: ${pair[0]} / ${pair[1]}');
      }
    });
  });
}
