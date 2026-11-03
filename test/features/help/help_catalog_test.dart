import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/help/domain/help_catalog.dart';
import 'package:book_review_app/features/help/domain/help_topic.dart';

void main() {
  group('HelpCatalog.allTopics', () {
    test('宣言順を維持し、チュートリアル全ステップ分を返す', () {
      final catalog = HelpCatalog();

      expect(catalog.allTopics, isNotEmpty);
      expect(
        catalog.allTopics.map((t) => t.title).toList(),
        ['書庫', '本を追加', 'レビュー', 'メモ・引用', '次に読む'],
      );
    });

    test('返すリストは呼び出し側の破壊から守られている', () {
      final catalog = HelpCatalog();
      expect(
        () => catalog.allTopics.add(
          const HelpTopic(id: 'x', title: 'x', body: 'x'),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('HelpCatalog.search', () {
    test('部分一致で絞り込む（宣言順を維持）', () {
      final catalog = HelpCatalog();

      final hits = catalog.search('レビュー');

      expect(hits.map((t) => t.title), ['レビュー']);
    });

    test('本文の語でもヒットする', () {
      final catalog = HelpCatalog();

      final hits = catalog.search('積ん読');

      expect(hits.map((t) => t.title), ['次に読む']);
    });

    test('空クエリは全件を宣言順で返す', () {
      final catalog = HelpCatalog();

      expect(catalog.search(''), catalog.allTopics);
      expect(catalog.search('   '), catalog.allTopics);
    });

    test('該当なしは空リスト', () {
      final catalog = HelpCatalog();

      expect(catalog.search('存在しない語句xyz'), isEmpty);
    });

    test('大文字小文字を無視する', () {
      final catalog = HelpCatalog(
        topics: const [
          HelpTopic(id: 'a', title: 'Reading Queue', body: '積読を管理する'),
          HelpTopic(id: 'b', title: 'メモ', body: 'Quote を残す'),
        ],
      );

      expect(catalog.search('reading').single.id, 'a');
      expect(catalog.search('READING').single.id, 'a');
      expect(catalog.search('qUoTe').single.id, 'b');
    });

    test('複数ヒット時も宣言順を維持する', () {
      final catalog = HelpCatalog(
        topics: const [
          HelpTopic(id: 'a', title: '本を追加', body: '追加の手順'),
          HelpTopic(id: 'b', title: '書庫', body: '本の一覧'),
          HelpTopic(id: 'c', title: 'レビュー', body: '本の感想'),
        ],
      );

      expect(catalog.search('本').map((t) => t.id), ['a', 'b', 'c']);
    });
  });
}
