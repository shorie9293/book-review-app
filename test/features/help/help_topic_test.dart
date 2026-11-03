import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/help/domain/help_catalog.dart';
import 'package:book_review_app/features/tutorial/presentation/tutorial_content.dart';

void main() {
  group('HelpTopic 一覧の健全性', () {
    test('id は一意である', () {
      final ids = HelpCatalog().allTopics.map((t) => t.id).toList();

      expect(ids.toSet().length, ids.length, reason: 'duplicate id: $ids');
      expect(ids, everyElement(isNotEmpty));
    });

    test('title と body は空でない', () {
      for (final topic in HelpCatalog().allTopics) {
        expect(topic.title.trim(), isNotEmpty, reason: 'empty title: ${topic.id}');
        expect(topic.body.trim(), isNotEmpty, reason: 'empty body: ${topic.id}');
      }
    });

    test('本文はチュートリアル文言を再利用している（二重管理しない）', () {
      final catalog = HelpCatalog();

      expect(catalog.allTopics.length, TutorialContent.pages.length);
      for (var i = 0; i < catalog.allTopics.length; i++) {
        expect(catalog.allTopics[i].title, TutorialContent.pages[i].title);
        expect(catalog.allTopics[i].body, TutorialContent.pages[i].body);
      }
    });
  });
}
