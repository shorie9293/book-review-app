import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/undo/domain/undo_buffer.dart';

/// UndoBuffer（削除の元に戻す用・単一スロット）の純粋試練。
void main() {
  group('UndoBuffer', () {
    test('初期状態は canUndo が false で peek/take は null', () {
      final buffer = UndoBuffer<String>();

      expect(buffer.canUndo, isFalse);
      expect(buffer.peek(), isNull);
      expect(buffer.take(), isNull);
    });

    test('push した値は peek で何度でも覗ける（消費しない）', () {
      final buffer = UndoBuffer<String>();

      buffer.push('削除した項目');

      expect(buffer.canUndo, isTrue);
      expect(buffer.peek(), '削除した項目');
      expect(buffer.peek(), '削除した項目');
      expect(buffer.canUndo, isTrue);
    });

    test('take は値を一度だけ返し、二度目は null（二重復元の防止）', () {
      final buffer = UndoBuffer<String>();
      buffer.push('一度きり');

      expect(buffer.take(), '一度きり');
      expect(buffer.canUndo, isFalse);
      expect(buffer.take(), isNull);
    });

    test('push で既存値は押し出され、押し出された旧値を返す', () {
      final buffer = UndoBuffer<String>();

      expect(buffer.push('先に削除'), isNull);
      expect(buffer.push('後に削除'), '先に削除');
      expect(buffer.peek(), '後に削除');
    });

    test('押し出された旧値は take で復元できない', () {
      final buffer = UndoBuffer<String>();
      buffer.push('旧');
      buffer.push('新');

      expect(buffer.take(), '新');
      expect(buffer.take(), isNull);
    });

    test('clear で保持値が破棄される', () {
      final buffer = UndoBuffer<String>();
      buffer.push('破棄対象');

      buffer.clear();

      expect(buffer.canUndo, isFalse);
      expect(buffer.take(), isNull);
    });

    test('clear 後も新しい値を push できる', () {
      final buffer = UndoBuffer<String>();
      buffer.push('一回目');
      buffer.clear();
      buffer.push('二回目');

      expect(buffer.take(), '二回目');
      expect(buffer.take(), isNull);
    });

    test('ジェネリック型を保持できる（オブジェクト）', () {
      final buffer = UndoBuffer<Map<String, int>>();
      final value = <String, int>{'minutes': 30};

      buffer.push(value);

      expect(buffer.take(), same(value));
    });
  });
}
