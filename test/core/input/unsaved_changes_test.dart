import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/input/unsaved_changes.dart';

void main() {
  group('UnsavedChangesGuard.isDirty', () {
    test('空のままなら未変更', () {
      expect(UnsavedChangesGuard.isDirty('', ''), isFalse);
    });

    test('本文を書き足したら変更あり', () {
      expect(UnsavedChangesGuard.isDirty('', 'あ'), isTrue);
    });

    test('前後の空白だけの差は未変更扱い', () {
      expect(UnsavedChangesGuard.isDirty('本文', '  本文 \n'), isFalse);
    });

    test('空白だけの入力は未変更扱い', () {
      expect(UnsavedChangesGuard.isDirty('', '   '), isFalse);
    });

    test('1文字消したら変更あり', () {
      expect(UnsavedChangesGuard.isDirty('本文です', '本文で'), isTrue);
    });
  });

  group('UnsavedChangesGuard.isAnyDirty', () {
    test('いずれか1つでも変われば true', () {
      expect(
        UnsavedChangesGuard.isAnyDirty(
          {'content': '本文', 'page': '12'},
          {'content': '本文', 'page': '13'},
        ),
        isTrue,
      );
    });

    test('全て空白差のみなら false', () {
      expect(
        UnsavedChangesGuard.isAnyDirty(
          {'content': '本文', 'page': '12'},
          {'content': ' 本文 ', 'page': ' 12 '},
        ),
        isFalse,
      );
    });

    test('片方にしか無いキーは変更として扱う', () {
      expect(
        UnsavedChangesGuard.isAnyDirty({'content': '本文'}, {'content': '本文', 'tags': 'a'}),
        isTrue,
      );
    });
  });

  group('UnsavedChangesGuard.confirmMessage', () {
    test('既定は破棄を問う文言', () {
      expect(UnsavedChangesGuard.confirmMessage(), contains('破棄'));
    });

    test('下書き保持時は下書きに残ると伝える', () {
      final message = UnsavedChangesGuard.confirmMessage(draftKept: true);
      expect(message, contains('下書き'));
      expect(message, isNot(contains('失われます')));
    });
  });
}
