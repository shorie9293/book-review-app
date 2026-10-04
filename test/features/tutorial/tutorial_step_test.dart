import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/tutorial/domain/tutorial_step.dart';

void main() {
  group('TutorialStep label', () {
    test('全ステップの label が非空であること', () {
      for (final step in TutorialStep.values) {
        expect(step.label, isNotEmpty, reason: '${step.name}.label が空');
      }
    });

    test('label が仕様どおりであること', () {
      expect(TutorialStep.bookshelf.label, '書庫');
      expect(TutorialStep.addBook.label, '本を追加');
      expect(TutorialStep.review.label, 'レビュー');
      expect(TutorialStep.notes.label, 'メモ・引用');
      expect(TutorialStep.queue.label, '次に読む');
    });

    test('label に重複がないこと', () {
      final labels = TutorialStep.values.map((s) => s.label).toSet();
      expect(labels.length, TutorialStep.values.length);
    });
  });

  group('TutorialStep description', () {
    test('全ステップの description が非空であること', () {
      for (final step in TutorialStep.values) {
        expect(step.description, isNotEmpty, reason: '${step.name}.description が空');
      }
    });

    test('description に重複がないこと', () {
      final descriptions = TutorialStep.values.map((s) => s.description).toSet();
      expect(descriptions.length, TutorialStep.values.length);
    });

    test('description が 120 字以内の案内文であること', () {
      for (final step in TutorialStep.values) {
        expect(step.description.length, lessThanOrEqualTo(120));
      }
    });
  });

  test('enum は 5 ステップであること', () {
    expect(TutorialStep.values.length, 5);
  });
}
