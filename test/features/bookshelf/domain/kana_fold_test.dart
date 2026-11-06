import 'package:book_review_app/core/text/kana_fold.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:flutter_test/flutter_test.dart';

Book _b(String id, {String title = '', String author = ''}) {
  return Book(id: id, title: title, author: author, isbn: '');
}

void main() {
  group('foldKana', () {
    test('ひらがなをカタカナへ畳む（U+3041..U+3096 を +0x60）', () {
      expect(foldKana('よみかた'), 'ヨミカタ');
      expect(foldKana('あいうえお'), 'アイウエオ');
      expect(foldKana('ゔ'), 'ヴ');
      expect(foldKana('ぁぃぅぇぉ'), 'ァィゥェォ');
    });

    test('小書きの ゕ / ゖ も ヵ / ヶ へ畳む', () {
      expect(foldKana('ゕ'), 'ヵ');
      expect(foldKana('ゖ'), 'ヶ');
      expect(foldKana('一ヶ月'), '一ヶ月');
      expect(foldKana('いっかげつ'), 'イッカゲツ');
    });

    test('半角カナを全角カタカナへ表引きする', () {
      expect(foldKana('ｱｲｳｴｵ'), 'アイウエオ');
      expect(foldKana('ｦｰｯﾝ'), 'ヲーッン');
      expect(foldKana('ﾊﾛｰ'), 'ハロー');
    });

    test('半角カナの濁点・半濁点を結合して 1 文字にする', () {
      expect(foldKana('ｶﾞｯｺｳ'), 'ガッコウ');
      expect(foldKana('ﾊﾟﾝ'), 'パン');
      expect(foldKana('ｳﾞｧｲｵﾘﾝ'), 'ヴァイオリン');
      expect(foldKana('ｻﾞｼﾞｽﾞｾﾞｿﾞ'), 'ザジズゼゾ');
      expect(foldKana('ﾋﾟﾋﾟﾋﾟ'), 'ピピピ');
    });

    test('結合できない濁点はそのまま残す（落とさない）', () {
      expect(foldKana('ｱﾞ'), contains('ﾞ'));
      expect(foldKana('ﾞ'), 'ﾞ');
    });

    test('全角カタカナ・ASCII・漢字は不変', () {
      expect(foldKana('カタカナ'), 'カタカナ');
      expect(foldKana('Flutter 1.0 ABC!'), 'Flutter 1.0 ABC!');
      expect(foldKana('吾輩猫'), '吾輩猫');
      expect(foldKana('漢字'), '漢字');
      expect(foldKana(''), '');
    });

    test('冪等（foldKana∘foldKana == foldKana）', () {
      const inputs = [
        'よみかた',
        'ｶﾞｯｺｳ',
        'ｳﾞｧｲｵﾘﾝ',
        '一ヶ月のヨミカタ',
        'Flutter入門 第2版',
        'ゕゖゔ',
        '',
      ];
      for (final input in inputs) {
        final once = foldKana(input);
        expect(foldKana(once), once, reason: 'input=$input');
      }
    });
  });

  group('LibraryQueryService.normalizeForSearch', () {
    test('ひらがなとカタカナを同一視する（既存 normalize は不変）', () {
      expect(LibraryQueryService.normalizeForSearch('よみかた'),
          LibraryQueryService.normalizeForSearch('ヨミカタ'));
      expect(LibraryQueryService.normalizeForSearch('よみかた'), 'ヨミカタ');
      // 既存 normalize の戻り値はかな畳み込みしない（互換維持）
      expect(LibraryQueryService.normalize('よみかた'), 'よみかた');
      expect(LibraryQueryService.normalize('ヨミカタ'), 'ヨミカタ');
    });

    test('半角カナ＋濁点も吸収する', () {
      expect(
        LibraryQueryService.normalizeForSearch('ｶﾞｯｺｳ'),
        LibraryQueryService.normalizeForSearch('がっこう'),
      );
    });
  });

  group('蔵書検索の統合（かな表記ゆれ吸収）', () {
    test('書名『ヨミカタ』が よみかた でヒットする', () {
      final books = [
        _b('1', title: 'ヨミカタ練習帳'),
        _b('2', title: '別の本'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'よみかた'),
      );
      expect(out.single.id, '1');
    });

    test('著者『カタカナ』が かたかな でヒットする', () {
      final books = [
        _b('1', title: '本', author: 'カタカナ 太郎'),
        _b('2', title: '本', author: '漢字 次郎'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'かたかな'),
      );
      expect(out.single.id, '1');
    });

    test('半角カナの書名がひらがなクエリでヒットする', () {
      final books = [
        _b('1', title: 'ｶﾞｯｺｳ日記'),
        _b('2', title: '会社日記'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'がっこう'),
      );
      expect(out.single.id, '1');
    });

    test('既存の意味論は不変: 全角英数・空白区切り・安定ソート', () {
      final books = [
        _b('1', title: 'Ｄａｒｔ入門'),
        _b('2', title: 'Yomikata 入門'),
        _b('3', title: 'ヨミカタ 入門'),
        _b('4', title: 'Java入門'),
      ];
      final out = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'ｄａｒｔ'),
      );
      expect(out.single.id, '1');

      final spaced = LibraryQueryService.apply(
        [_b('1', title: '徒然草', author: '吉田 兼好')],
        const LibraryQuery(text: '吉田　兼好'),
      );
      expect(spaced.single.id, '1');

      final sorted = LibraryQueryService.apply(
        books,
        const LibraryQuery(
          text: 'ヨミカタ 入門',
          sortOrder: LibrarySortOrder.addedAtDesc,
        ),
      );
      // 空白区切りの部分一致（従来どおり文字列全体の contains）で 3 のみ
      expect(sorted.single.id, '3');
    });

    test('ひらがな・カタカナ混在でも同一結果（順序も安定）', () {
      final books = [
        _b('a', title: 'ヨミカタ入門'),
        _b('b', title: 'よみかた入門'),
        _b('c', title: 'ヨミカタ入門'),
      ];
      final hira = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'よみかた'),
      );
      final kata = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'ヨミカタ'),
      );
      expect(hira.map((b) => b.id).toList(), ['a', 'b', 'c']);
      expect(kata.map((b) => b.id).toList(), ['a', 'b', 'c']);
    });
  });
}
