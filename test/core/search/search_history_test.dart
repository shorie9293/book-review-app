import 'package:book_review_app/core/search/search_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchHistory.add', () {
    test('新しい語を先頭に積み、新しい順で保持する', () {
      final history = SearchHistory().add('夏目漱石').add('吾輩は猫である').add('読書');

      expect(history.entries, ['読書', '吾輩は猫である', '夏目漱石']);
    });

    test('前後の空白を除去する（半角・全角とも）', () {
      final history = SearchHistory().add('  吾輩  ').add('\u3000坊っちゃん\u3000');

      expect(history.entries, ['坊っちゃん', '吾輩']);
    });

    test('全角空白を半角空白へ変換し、連続空白を1個に畳む', () {
      final history = SearchHistory().add('夏目\u3000\u3000漱石');

      expect(history.entries.first, '夏目 漱石');
    });

    test('空文字・空白のみは履歴に加えない（同一インスタンスを返す）', () {
      final base = SearchHistory().add('吾輩');
      final afterEmpty = base.add('');
      final afterSpaces = base.add('  \u3000  ');

      expect(afterEmpty.entries, ['吾輩']);
      expect(afterSpaces.entries, ['吾輩']);
      expect(identical(afterEmpty, base), isTrue);
    });

    test('大小文字を無視した重複は先頭へ移動し、表記を更新する', () {
      final history =
          SearchHistory().add('soseki').add('Natsume').add('SOSEKI');

      expect(history.entries, ['SOSEKI', 'Natsume']);
    });

    test('同じ語を続けて追加しても重複しない', () {
      final history = SearchHistory().add('吾輩').add('吾輩');

      expect(history.entries, ['吾輩']);
    });

    test('上限8件を超えると古いものから捨てる', () {
      var history = SearchHistory();
      for (var i = 1; i <= 12; i++) {
        history = history.add('語$i');
      }

      expect(history.length, SearchHistory.maxEntries);
      expect(history.entries.first, '語12');
      expect(history.entries.last, '語5');
      expect(history.entries, isNot(contains('語4')));
    });

    test('保持している entries は変更できない', () {
      final history = SearchHistory().add('吾輩');

      expect(
        () => history.entries.add('他人'),
        throwsUnsupportedError,
      );
    });
  });

  group('SearchHistory.encode / decode', () {
    test('往復で内容と順序が保たれる', () {
      final history = SearchHistory().add('夏目漱石').add('吾輩は猫である 上');

      final restored = SearchHistory.decode(history.encode());

      expect(restored.entries, history.entries);
    });

    test('null・空文字からは空の履歴を返す（例外なし）', () {
      expect(SearchHistory.decode(null).isEmpty, isTrue);
      expect(SearchHistory.decode('').isEmpty, isTrue);
    });

    test('破損した JSON からは空の履歴を返す（例外なし）', () {
      expect(SearchHistory.decode('{not json').isEmpty, isTrue);
      expect(SearchHistory.decode('"文字列"').isEmpty, isTrue);
      expect(SearchHistory.decode('{"a":1}').isEmpty, isTrue);
    });

    test('配列内の非文字列要素は無視し、重複と空を正規化する', () {
      final restored =
          SearchHistory.decode('["吾輩", 1, null, "", " 吾輩 ", "草枕"]');

      expect(restored.entries, ['吾輩', '草枕']);
    });

    test('上限を超える保存データも8件に切り詰める', () {
      final raw = '["語1","語2","語3","語4","語5","語6","語7","語8","語9","語10"]';

      final restored = SearchHistory.decode(raw);

      expect(restored.length, SearchHistory.maxEntries);
      expect(restored.entries.first, '語1');
      expect(restored.entries.last, '語8');
    });
  });

  group('SearchHistory.normalize', () {
    test('全角空白・連続空白・前後空白を一括で正規化する', () {
      expect(SearchHistory.normalize('\u3000夏目\u3000\u3000 漱石 '), '夏目 漱石');
    });

    test('正規化は冪等である', () {
      const samples = ['吾輩', ' 夏目 漱石 ', '\u3000あ\u3000い\u3000', ''];
      for (final sample in samples) {
        final once = SearchHistory.normalize(sample);
        expect(SearchHistory.normalize(once), once);
      }
    });
  });
}
